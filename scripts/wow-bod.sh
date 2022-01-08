#!/bin/sh
aws ec2 start-instances --instance-ids i-02c154a4703a33024
sleep 120
ssh pk -t /home/ubuntu/projects/trinityCore-docker/scripts/wotlk-start.sh
