#
# -------------
## Commands for quickly spinning up GCP instances
#  @lucas
#  -----------
#

.DEFAULT_GOAL := help
TIME := "$$(date +'%Y%m%d-%H%M%S')"
SHELL := /usr/bin/env bash
GCP_SSH ?= gcloud compute ssh $(INSTANCE) --zone $(ZONE) -- -A

REGION ?= us-central1
ZONE ?= $(REGION)-c
PROJECT ?= tongfamily
INSTANCE ?= a100-instance
USERS ?= rich
DISK ?= /mnt/data

## help: you are reading this now
#.PHONY: help
#help:
#    @sed -n 's/^##//p' $(MAKEFILE_LIST)

# https://stackoverflow.com/questions/35599414/get-the-default-gcp-project-id-with-a-cloud-sdk-cli-one-liner
## default: set default zone and region and project and configure ssh with local forwarding
##          for applications like jupyter notebook add LocalForward 8888 localhost:8888
.PHONY: default
default:
	if [[ -z $$(gcloud config get compute/region) ]]; then \
 		gcloud config set compute/region $(REGION); \
	fi; \
	if [[ -z $$(gcloud config get compute/zone) ]]; then \
		gcloud config set compute/zone $(ZONE); \
	fi; \
	if ! gcloud config get-value project | grep -q $(PROJECT); then \
		gcloud config set project $(PROJECT); \
	fi; \
	gcloud compute project-info add-metadata \
		--metadata google-compute-default-region=$(REGION),google-compute-default-zone=$(ZONE); \
	gcloud compute config-ssh


## gcp-central-2a: create an Ubuntu 2xV100 instance in central-2a region
.PHONY: gcp-central-2a
gcp-central-2a:
	gcloud beta compute instances create ubuntu-gpu-2-${TIME} \
	  --project netdrones \
	  --zone us-central1-a \
	  --custom-cpu 12 \
	  --custom-memory 64 \
	  --accelerator type=nvidia-tesla-v100,count=2 \
	  --maintenance-policy TERMINATE --restart-on-failure \
	  --source-machine-image ubuntu-cuda110 \

## connect-central-2a: connect to Ubuntu 2xV100 in central-2a region.
.PHONY: connect-central-2a
connect-central-2a:
	gcloud compute ssh "$$(gcloud compute instances list --filter="name~'gpu-2'" | head -n 1 | awk '{print $$2}')" \
	  --project netdrones \
	  --zone us-central1-a \
	  -- -A

## gcp-central-2c: create to Ubuntu 2xV100 in central-2c region.
.PHONY: gcp-central-2c
gcp-central-2c:
	gcloud beta compute instances create ubuntu-gpu-2-${TIME} \
	  --project netdrones \
	  --zone us-central1-c \
	  --custom-cpu 12 \
	  --custom-memory 64 \
	  --accelerator type=nvidia-tesla-v100,count=2 \
	  --maintenance-policy TERMINATE --restart-on-failure \
	  --source-machine-image ubuntu-cuda110 \

## connect-central-2c: connect to Ubuntu 2xV100 in central-2c region.
.PHONY: connect-central-2c
connect-central-2c:
	gcloud compute ssh "$$(gcloud compute instances list --filter="name~'gpu-2'" | head -n 1 | awk '{print $$2}')" \
	  --project netdrones \
	  --zone us-central1-c \
	  -- -A

## gcp-central-1a: create to Ubuntu 2xV100 in central-2a region.
.PHONY: gcp-central-1a
gcp-central-1a:
	gcloud beta compute instances create ubuntu-gpu-1-${TIME} \
	  --project netdrones \
	  --zone us-central1-a \
	  --custom-cpu 12 \
	  --custom-memory 64 \
	  --accelerator type=nvidia-tesla-v100,count=1 \
	  --maintenance-policy TERMINATE --restart-on-failure \
	  --source-machine-image ubuntu-cuda110 \
	  --scopes https://www.googleapis.com/auth/cloud-platform \
	  --service-account process@netdrones.iam.gserviceaccount.com

## connect-central-1a: connect to Ubuntu 2xV100 in central-1a region.
.PHONY: connect-central-1a
connect-central-1a:
	gcloud compute ssh "$$(gcloud compute instances list --filter="name~'gpu-1'" | head -n 1 | awk '{print $$2}')" \
	  --project netdrones \
	  --zone us-central1-c \
	  -- -A

## gcp-central-1c: create to Ubuntu 2xV100 in central-1c region.
.PHONY: gcp-central-1c
gcp-central-1c:
	gcloud beta compute instances create ubuntu-gpu-1-${TIME} \
	  --project netdrones \
	  --zone us-central1-c \
	  --custom-cpu 12 \
	  --custom-memory 64 \
	  --accelerator type=nvidia-tesla-v100,count=1 \
	  --maintenance-policy TERMINATE --restart-on-failure \
	  --source-machine-image ubuntu-cuda110 \
	  --scopes https://www.googleapis.com/auth/cloud-platform \
	  --service-account process@netdrones.iam.gserviceaccount.com

## connect-central-1c: connect to Ubuntu 2xV100 in central-1c region.
.PHONY: connect-central-1c
connect-central-1c:
	gcloud compute ssh "$$(gcloud compute instances list --filter="name~'gpu-1'" | head -n 1 | awk '{print $$2}')" \
	  --project netdrones \
	  --zone us-central1-c \
	  -- -A

## gcp-a100: create to Ubuntu A100
.PHONY: gcp-a100
gcp-a100:
	gcloud beta compute instances create $(INSTANCE) \
	  --project netdrones \
	  --zone us-central1-c \
	  --machine-type a2-highgpu-1g \
	  --maintenance-policy TERMINATE \
	  --restart-on-failure \
	  --boot-disk-size=200 \
	  --source-machine-image a100-vm \
	  --scopes https://www.googleapis.com/auth/cloud-platform \
	  --service-account process@netdrones.iam.gserviceaccount.com

## start-a100: Restart Ubuntu A100 instance in default $ZONE
.PHONY: start-a100
start-a100:
	gcloud compute instances start $(INSTANCE) --zone $(ZONE)

# https://cloud.google.com/compute/docs/instances/view-ip-address#gcloud
## ip-a100: get the IP of the A100 instance
.PHONY: ip-a100
ip-a100:
	gcloud compute instances describe $(INSTANCE) \
		--format 'get(networkInterfaces[0].accessConfigs[0].natIP)'

## connect-a100: connect to Ubuntu A100
.PHONY: connect-a100
connect-a100:
	$(GCP_SSH)

## stop-a100: stop A100
.PHONY: stop-a100
stop-a100:
	gcloud compute instances stop $(INSTANCE) --zone $(ZONE)

# https://cloud.google.com/compute/docs/disks/add-persistent-disk
## create-disk: create and attach disk to $(INSTANCE)
.PHONY: create-disk
create-disk:
	if ! gcloud compute disks list --filter="name~'data-images'" | \
		grep -q data-images; then \
			gcloud compute disks create data-images --size 2TB --zone $(ZONE); \
	fi; \
	if ! gcloud compute instances describe $(INSTANCE) --zone=$(ZONE) \
		--format="value(disks[].source)" | grep -q data-image; then \
			gcloud compute instances attach-disk $(INSTANCE) \
				--disk data-images \
				--zone $(ZONE); \
	fi

## mount-disk: mount a formatted disk into $INSTANCE then reboot
.PHONY: mount-disk
mount-disk:
	$(GCP_SSH) \
		' \
			for ACCOUNT in $(USERS); do \
				if ! group "$$ACCOUNT" | grep -q staff; then \
					useradd -a -G staff "$$ACCOUNT" \
				fi \
			done && \
			DISK=$$(lsblk | grep ^sd | tail -n 1 | cut -d " " -f 1) && \
			eval "$$(blkid -o export $$DISK)" && \
			mkdir -p $(DATA_DISK) && chmod a+w $(DATA_DISK) && \
			if  ! grep -q "^$$UUID" /etc/fstab; then \
				sudo tee -a /etc/fstab <<<"UUID=$$UUID $(DATA_DISK) $$TYPE discard,defaults,nofail"; \
			fi \
		'

##
## warning this wipes out the contents of the disk!!!
## format-disk: run inside the instance once you have run create disk
##
.PHONY: format-disk
format-disk: create-disk
	$(GCP_SSH) \
		' \
			DISK=$$(lsblk | grep ^sd | tail -n 1 | cut -d " " -f 1); \
			sudo mkfs.ext4 -m 0 \
				-E lazy_itable_init=0,lazy_journal_init=0,discard \
				/dev/$$DISK \
		'
