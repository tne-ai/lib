#!/usr/bin/env bash
## vim: se noet ts=4 sw=4:
##
## Avahi publishing
## Either can do static publish via a file
## Or dynamic publishing by running a process
## Use the later when the service is only up temporarily
##

# avahi_publish -f service hostname protocol port [text]
# -d means add device info
# Adds an nice Mac icon as well
avahi_publish() {
	if [[ ! $OSTYPE =~ linux ]]; then
		log_verbose for linux only
		return
	fi
	local DEVICE_INFO=false
	while [[ $1 =~ ^- ]]; do
		log_verbose "found flag $1"
		if [[ $1 == -f ]]; then
			log_verbose "Set DEVICE_INFO"
			local DEVICE_INFO=true
			shift
		fi
		flags+=("$1")
		shift
	done
	log_verbose "DEVICE_INFO=$DEVICE_INFO"
	# http://www.win.tue.nl/~johanl/educ/IoT-Course/mDNS-SD%20Tutorial.pdf
	# note this file must end in .service
	local dir="/etc/avahi/services"
	local service="${1:-nfs}"
	local service_file="$dir/$service.service"
	local name="${2:-"$HOSTNAME nfs"}"
	local protocol="${3:-"_nfs._tcp"}"
	local port="${4:-2049}"
	local text="${5:-""}"

	if [[ -e $service_file ]]; then
		log_verbose "$service_file already exists do not overwrite"
		return
	fi

	#log_verbose "Ubuntu 14.04 does not like this header and throws an error"
	#<?xml version="1.0" standalone='no'?><!--*-nxml-*-->
	#<!DOCTYPE service=group SYSTEM "avahi-service.dtd">
	# make sure you are using tabs as the xml must not be indented
	log_verbose "add service group to $service_file"
	sudo tee "$service_file" <<-EOF
		<service-group>
		  <name replace-wildcards="yes">$name</name>
		  <service>
		     <type>$protocol</type>
		     <port>$port</port>
	EOF
	if [[ -n $text ]]; then
		log_verbose "optionally put in a text description"
		sudo tee -a "$service_file" <<<"    <txt-record>$text</txt-record>"
	fi
	log_verbose "end the service"
	sudo tee -a "$service_file" <<-EOF
		  </service>
	EOF
	# http://simonwheatley.co.uk/2008/04/avahi-finder-icons/
	if $DEVICE_INFO; then
		log_verbose "Put optional device info in the finder icon"
		sudo tee -a "$service_file" <<-EOF
			  <service>
			       <type>_device-info._tcp</type>
			       <port>0</port>
			       <txt-record>model=RackMac</txt-record>
			   </service>
		EOF
	fi
	sudo tee -a "$service_file" >/dev/null <<-EOF
		</service-group>
	EOF

	# with Ubuntu 16.04 the name comes out as capital letters use -i
	# http://droptips.com/using-grep-and-ignoring-case-case-insensitive-grep
	# need -a since /var/log/syslog has some binary characters in it
	# https://unix.stackexchange.com/questions/335716/grep-returns-binary-file-standard-input-matches-when-trying-to-find-a-string
	# we do not search for $name because it may be %h for the hostname
	if ! sudo grep -qa "avahi-daemon.*/services/$service.service.*successfully established" /var/log/syslog; then
		log_verbose "publishing $service did not appear in /var/log/syslog"
		return 1
	fi

}

# avahi_publish_temp_start name type port text
avahi_publish_start() {
	# The equivalent way for a temporary service
	#http://www.noah.org/wiki/Avahi_Notes
	# Needs to go in background
	if [[ $OSTYPE =~ darwin ]]; then
		log_verbose linux only
		return
	fi
	local name="${1:-"Samba on $HOSTNAME"}"
	local protocol="${2:-"_smb"}"
	local port="${3:-445}"
	local text="${4:-""}"
	if ! pgrep "avahi-publish-service $name $protocol $port $text"; then
		avahi-publish-service "$name" "$protocol" "$port" "$text" &
	fi
}

# avahi_publish_temp_stop name type port text
avahi_publish_stop() {
	if [[ $OSTYPE =~ darwin ]]; then
		log_verbose linux only
		return
	fi
	local name="${1:-"Samba on $HOSTNAME"}"
	local protocol="${2:-"_smb"}"
	local port="${3:-445}"
	local text="${4:-""}"
	pkill avahi-public-service "$name" "$protocol" "$port" "$text"
}
