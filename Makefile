###############################################################################
#
#
#
###############################################################################

USER := ubuntu

GIT_BRANCH := 3.3.5
GIT_URL := git://github.com/TrinityCore/TrinityCore.git

#CLIENT_FOLDER := /home/$(USER)/Desktop/wotlk
CLIENT_FOLDER := "/mnt/c/WOW/World of Warcraft - WoTLK"

# path trinity will be built to. Must be abs path, /opt/trinitycore is highly
# recommended, this will be the same path used in docker container
BUILD_FOLDER := /srv/wow/trinitycore/3.3.5a

# path trinity source will be checked out to
SRC_FOLDER := /home/$(USER)/projects/wow/TrinityCore

# path container zips will be placed. These can be transferred to other systems to
# mount. Assuming you're not going to push a 6+gig docker image to the official docker
# hub, and you probably don't have a private container repo, so we're transferring
# images as bin files
CONTAINER_FOLDER := /home/$(USER)/projects/wow/TrinityContainers

# overbook threads to use for build. You want to build at full tilt, it speeds the
# build up tremendously
BUILD_THREAD_COUNT := 18

# Look into manually grabbing the latest tag...
BUILD_TAG := TDB335.21111
#BUILD_TAG_DATE := TDB335.21101

#RESTORE_TIMESTAMP := 20211112
#RESTORE_TIMESTAMP := 202111140030597449897
#RESTORE_TIMESTAMP := 202111220155552903968
#RESTORE_TIMESTAMP := 202111222345242734107
#RESTORE_TIMESTAMP := 202111240433600628100
#RESTORE_TIMESTAMP := 202111250321518735700
#RESTORE_TIMESTAMP := 202111272310268209276
RESTORE_TIMESTAMP := 202111290113704408071

##
##
##
real-clean: clean-compile-dir clean-build-dir clean-conduit-dir \
	clean-container-dir clean-client-dir clean-trinity-db-zip clean-mysql-dir

clean-compile-dir:
	-rm -rf $(SRC_FOLDER)/build

clean-build-dir:
	sudo rm -rf $(BUILD_FOLDER)

clean-container-dir:
	rm -f $(CONTAINER_FOLDER)/*

clean-mysql-dir: docker-rm-all-images
	-sudo rm -rf mysql/
	-sudo rm -rf dbrestore/
	-sudo rm -rf dbdumps/

clean-client-dir:
	rm -rf $(CLIENT_FOLDER)/Buildings
	rm -rf $(CLIENT_FOLDER)/Cameras
	rm -rf $(CLIENT_FOLDER)/dbc
	rm -rf $(CLIENT_FOLDER)/maps
	rm -rf $(CLIENT_FOLDER)/mmaps
	rm -rf $(CLIENT_FOLDER)/vmaps

##
##
##
create-compile-dir:
	mkdir -p $(SRC_FOLDER)/build

create-build-dir:
	sudo mkdir -p $(BUILD_FOLDER)
	sudo chown $(USER) -R $(BUILD_FOLDER)

create-data-dir:
	mkdir -p $(BUILD_FOLDER)/data

create-sql-dir:
	mkdir -p $(BUILD_FOLDER)/sql

create-log-dir:
	mkdir -p $(BUILD_FOLDER)/log

create-container-dir:
	mkdir -p $(CONTAINER_FOLDER)

create-conduit-dir:
	mkdir -p conduit

clean-conduit-dir:
	-rm -f conduit/*.sql
	-rm -f conduit/tpwd
	-rm -f conduit/rpwd

##
##
##
git-clone-trinity:
	@cd $(SRC_FOLDER) || git clone -b $(GIT_BRANCH) $(GIT_URL) $(SRC_FOLDER)

git-checkout-build-tag:
	@cd $(SRC_FOLDER) && git checkout $(BUILD_TAG)

##
##
##
cmake:
	cd $(SRC_FOLDER)/build && cmake ../ -DCMAKE_INSTALL_PREFIX=$(BUILD_FOLDER)

rmake:
	cd $(SRC_FOLDER)/build && make -j $(BUILD_THREAD_COUNT)

make-install:
	cd $(SRC_FOLDER)/build && make install

boulder: prereqs create-build-dir git-clone-trinity create-compile-dir \
              git-checkout-build-tag cmake rmake make-install

##
## System setup
##
prereqs:
	sudo apt-get update
	sudo apt-get install \
		git clang cmake make gcc g++ libmariadb-dev libmariadb-dev-compat \
		libssl-dev libbz2-dev libreadline-dev libncurses-dev libboost-all-dev \
		p7zip-full libmariadb-client-lgpl-dev-compat pwgen
	sudo update-alternatives --install /usr/bin/cc cc /usr/bin/clang 100
	sudo update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang 100

##
## extract data from WoW client, this is where the real time penalty hits
##
client-extract: clean-client-dir mapextractor vmap4extractor vmap4assembler mmaps_generator

mapextractor: create-data-dir
	cd $(CLIENT_FOLDER) && $(BUILD_FOLDER)/bin/mapextractor
	cp -r $(CLIENT_FOLDER)/dbc $(CLIENT_FOLDER)/maps $(BUILD_FOLDER)/data

vmap4extractor:
	cd $(CLIENT_FOLDER) && $(BUILD_FOLDER)/bin/vmap4extractor
	mkdir -p $(CLIENT_FOLDER)/vmaps

vmap4assembler:
	cd $(CLIENT_FOLDER) && $(BUILD_FOLDER)/bin/vmap4assembler Buildings vmaps
	cp -r $(CLIENT_FOLDER)/vmaps $(BUILD_FOLDER)/data

mmaps_generator:
	mkdir -p $(CLIENT_FOLDER)/mmaps
	cd $(CLIENT_FOLDER) && $(BUILD_FOLDER)/bin/mmaps_generator
	cp -r $(CLIENT_FOLDER)/mmaps $(BUILD_FOLDER)/data

full-boulder: boulder client-extract

fresh-boulder: real-clean full-boulder

##
## Database related targets
##
db-pull: cp-src-sql wget-trinity-db-fragment unzip-trinity-db-fragment \
           clean-trinity-db-zip

cp-src-sql:
	cp -R $(SRC_FOLDER)/sql $(BUILD_FOLDER)

wget-trinity-db-fragment:
	./scripts/get-tagged-db.sh $(BUILD_FOLDER) $(SRC_FOLDER) $(BUILD_TAG)

unzip-trinity-db-fragment:
	7z x $(BUILD_FOLDER)/bin/fulldb.7z -o$(BUILD_FOLDER)/bin -aoa

clean-trinity-db-zip:
	rm $(BUILD_FOLDER)/bin/fulldb.7z

##
## docker related targets
##
docker-create: create-log-dir docker-build-image docker-tag-image docker-save-image docker-load-image

docker-build-image:
	cd $(BUILD_FOLDER) && docker build -f $(PWD)/DockerFile -t trinitycore .

# Use docker save to pack our container to a tar file, then zip that because it's giant AF and we will almost
# certainly want to transfer it to another server to host. Note that the container has already been tagged to
# match the TrinityCore tag we built from.
docker-tag-image:
	docker tag trinitycore:latest trinitycore:$(BUILD_TAG)

docker-save-image: create-container-dir
	docker save trinitycore:$(BUILD_TAG) > $(CONTAINER_FOLDER)/trinitycore-$(BUILD_TAG).tar

docker-load-image:
	docker load -i $(CONTAINER_FOLDER)/trinitycore-$(BUILD_TAG).tar

docker-rm-image: docker-rm-containers
	-docker rmi trinitycore:$(BUILD_TAG) trinitycore:latest

docker-rm-containers:
	-docker rm trinity-db trinity-world trinity-auth

docker-rm-all-images: docker-rm-image
	-docker rmi mariadb:10.5.1

##
## docker-compose targets
##
containers-up:
	docker-compose up -d

containers-down:
	docker-compose down

system-up: containers-down containers-up world-start auth-start world-status auth-status

##
##
##
world-shell:
	docker exec -it trinity-world bash

world-start:
	docker exec -it trinity-world bash -c "systemctl start worldserver.service"

world-status:
	-docker exec -it trinity-world bash -c "systemctl status worldserver.service"

world-stop:
	-docker exec -it trinity-world bash -c "systemctl stop worldserver.service"

world-logs:
	docker exec -it trinity-world bash -c \
       'tail -f $(BUILD_FOLDER)/log/world-{game,db,server,gm}.log'

auth-shell:
	docker exec -it trinity-auth bash

auth-start:
	docker exec -it trinity-auth bash -c "systemctl start authserver.service"

auth-status:
	-docker exec -it trinity-auth bash -c "systemctl status authserver.service"

auth-stop:
	-docker exec -it trinity-auth bash -c "systemctl stop authserver.service"

auth-logs:
	docker exec -it trinity-auth bash -c \
      'tail -f $(BUILD_FOLDER)/log/authserver.log'

##
##
##
db-shell:
	docker exec -it trinity-db bash

db-create:
	[ -f conduit/tpwd ] || pwgen -c -n -1 12 > conduit/tpwd
	-@rm -f conduit/trinity-db-create.sh
	-@rm -f conduit/create_mysql.sql
	cp $(BUILD_FOLDER)/sql/create/create_mysql.sql conduit/
	cp -p scripts/trinity-db-create.sh conduit/
	sed -i "s/ED BY 'trinity'/ED BY '`cat conduit/tpwd`'/" conduit/create_mysql.sql
	docker exec -it trinity-db '/var/trinityscripts/trinity-db-create.sh'
	rm -f conduit/trinity-db-create.sh
	rm -f conduit/create_mysql.sql

db-drop:
	-@rm -f conduit/trinity-db-drop.sh
	-@rm -f conduit/drop_mysql.sql
	cp $(BUILD_FOLDER)/sql/create/drop_mysql.sql conduit/
	cp -p scripts/trinity-db-drop.sh conduit/
	docker exec -it trinity-db '/var/trinityscripts/trinity-db-drop.sh'
	rm -f conduit/trinity-db-drop.sh
	rm -f conduit/drop_mysql.sql

db-restore:
	-@rm -f conduit/trinity-db-auth-realmlist-address-update.sh
	-@rm conduit/trinity-db-restore.sh
	-@rm conduit/$(RESTORE_TIMESTAMP)*.sql
	-cp local-sql/$(RESTORE_TIMESTAMP)*.sql conduit/
	cp -p scripts/trinity-db-restore.sh conduit/
	cp -p scripts/trinity-db-auth-realmlist-address-update.sh conduit/
	cp -p local-sql/auth-realmlist-address.sql conduit/
	docker exec -it trinity-db '/var/trinityscripts/trinity-db-restore.sh'
	docker exec -it trinity-db '/var/trinityscripts/trinity-db-auth-realmlist-address-update.sh'
	rm -f conduit/trinity-db-restore.sh
	rm -f conduit/$(RESTORE_TIMESTAMP)*.sql
	rm -f conduit/trinity-db-auth-realmlist-address-update.sh
	rm -f conduit/auth-realmlist-address.sql

db-backup:
	-@rm -f conduit/trinity-db-backup.sh
	-@rm -f conduit/*.sql
	cp -p scripts/trinity-db-backup.sh conduit/
	docker exec -it trinity-db '/var/trinityscripts/trinity-db-backup.sh'
	rm -f conduit/trinity-db-backup.sh
	mv -n conduit/*.sql local-sql
