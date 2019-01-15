##File system##
###############
#create zpool cache drive with two drives in mirrored mode
sudo zpool create -f Cache mirror -m /${CACHE_MOUNTPOINT}  ${DISK}  ${DISK}
#create zpool storage drive in raidz2 mode for snapshotting, etc
sudo zpool create -f Storage raidz2 -m /${STORAGE_MOUNTPOINT}  ${DISK}  ${DISK} ${DISK}  ${DISK}  ${DISK}
##.....add as many disks as you have connected

##ZFS Mounpoint Configuration -- repeat for each drive you want to mount accordingly (cache, storage, etc) and based on how you want to mount them

#create zpool mountpoints for Docker
sudo zfs create -o mountpoint=/var/lib/docker  ${CACHE_MOUNTPOINT}/docker
sudo zfs set mountpoint=/${CACHE_MOUNTPOINT}  ${CACHE_MOUNTPOINT}/docker
sudo mv /var/lib/docker /var/lib/docker.bk
sudo rm -rf /var/lib/docker
sudo ln -s /${CACHE_MOUNTPOINT}/docker /var/lib/

#create zpool mountpoints for storage, caching, etc drives
[${DRIVENAME}]
    comment = ${DRIVENAME}
    path = /mnt/${STORAGE_MOUNTPOINT}
    read only = no
    browsable = yes
    guest ok = yes
    create mask = 0777

sudo chown -R ${DOCKER_USER}:${DOCKER_GROUP} /mnt/${STORAGE_MOUNTPOINT}
##Install Docker for Ubuntu 18.10
sudo apt install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic test"
sudo apt install docker-ce
sudo systemctl start docker
#add yourself to docker group
sudo usermod -aG docker ${USER}
#add yourself to docker sudoers
su - ${USER}
#check yourself
id -nG

#Kerberos/AD Joining Bits
#<<<This isn't done because I haven't abstracted it yet
${DO_SOMETHING_WITH_THIS}

#Create Samba Mounts for AD/Win/Mac File Browsing
#<<<This isn't done because I haven't abstracted it yet
${DO_SOMETHING_WITH_THIS}
sudo nano /etc/samba/smb.conf
${DO_SOMETHING_WITH_THIS}

##Docker Container Installs##
###########

#ELK: Elasticsearch, Logstash, Kibana Docker
docker run -d --name elk -v /${CACHE_MOUNTPOINT}/logstash:/opt/logstash -v /${CACHE_MOUNTPOINT}/kibana:/opt/kibana -v /${CACHE_MOUNTPOINT}/elasticsearch:/var/lib/elasticsearch -p 5601:5601 -p 9200:9200 -p 5044:5044 -e PGID=${DOCKER_USER} -e PUID=${DOCKER_USER}  -e ${LOCAL_TIMEZONE_CODE} sebp/elk

#Emby Media Manager
docker run -d --name=emby -v /${CACHE_MOUNTPOINT}/emby:/config -v /${STORAGE_MOUNTPOINT}/Media:/mnt/media -p 8096:8096 -p 8920:8920 -e UID=1000 -e GID=999 -e ${LOCAL_TIMEZONE_CODE} -e GIDLIST=44 emby/embyserver:latest

#Filebot Media File Manager
docker run -d --name=filebot --restart=always -v /${CACHE_MOUNTPOINT}/filebot:/config -e USER_ID=${DOCKER_USER} -e GROUP_ID=${DOCKER_GROUP} -v /etc/localtime:/etc/localtime:ro -e ${LOCAL_TIMEZONE_CODE} -v /${STORAGE_MOUNTPOINT}/${FILE_PATH}:/storage:rw -p 5800:5800 jlesage/filebot

#Home Assistant Home Automation Integrator
####This assumes use of an Aeotec Gen 5 USB Z-Wave Stick
docker run -d --net=host --name=homeassistant -v /${CACHE_MOUNTPOINT}/home-assistant:/config --device /dev/ttyACM0:/dev/ttyACM0 -v /etc/localtime:/etc/localtime:ro -e PUID=1000 -e PGID=996 homeassistant/home-assistant

#Homebridge Home Automation Integrator
sudo apt-get install libavahi-compat-libdnssd-dev
##^prerequisite for this to work right
docker run -d --restart=always --net=host --name=homebridge -e PUID=${DOCKER_USER} -e PGID=${DOCKER_USER} -e ${LOCAL_TIMEZONE_CODE} -v /${CACHE_MOUNTPOINT}/homebridge:/homebridge oznu/homebridge

#Hydra Media Indexer Utility
docker run -d --name hydra --restart=always -v /${CACHE_MOUNTPOINT}/hydra:/config -v /${STORAGE_MOUNTPOINT}/${NZB_FOLDER}/nzb:/nzb_downloads -e PGID=${DOCKER_GROUP} -e PUID=${DOCKER_USER} -e ${LOCAL_TIMEZONE_CODE} -p 5075:5075 linuxserver/hydra

#Jackett Media Indexer Utility
docker run -d --name jackett --restart=always -v /${CACHE_MOUNTPOINT}/jackett:/config -e PGID=${DOCKER_USER} -e PUID=${DOCKER_USER} -e ${LOCAL_TIMEZONE_CODE} -v /etc/localtime:/etc/localtime:ro -p 9117:9117 linuxserver/jackett

#LetsEncrypt DNS Certificate Provider
docker run -it --name certbot -v /${CACHE_MOUNTPOINT}/letsyencrypt:/etc/letsencrypt -v /var/lib/letsencrypt:/var/lib/letsencrypt -v /${CACHE_MOUNTPOINT}/letsencrypt/api:/secrets certbot/dns-google certonly --dns-google --dns-google-credentials /secrets/google.json --dns-google-propagation-seconds 120 --server https://acme-v02.api.letsencrypt.org/directory -d ${DOMAIN}

#MongoDB Database Enginer (for Unifi Controller)
docker run -d --name=mongoDB --restart=always --network=host -v /etc/localtime:/etc/localtime:ro -e ${LOCAL_TIMEZONE_CODE} -v /${CACHE_MOUNTPOINT}/mongoDB/db:/data/db -v /${CACHE_MOUNTPOINT}/mongoDB/configdb:/data/configdb -v /${CACHE_MOUNTPOINT}/mongoDB/mongo:/etc/mongo mongo:latest

#NZBGet Newsgroup Downloader
docker run -d --name=nzbget --restart=always -p 6799:6789 -e PUID=${DOCKER_USER} -e PGID=${DOCKER_USER} -e ${LOCAL_TIMEZONE_CODE} -v /${CACHE_MOUNTPOINT}/nzbget:/config -v /${STORAGE_MOUNTPOINT}/${NZB_FOLDER}:/nzb_downloads linuxserver/nzbget

#Observium
docker run -d --name=observium -p 8668:8668 -e ${LOCAL_TIMEZONE_CODE} -v /${CACHE_MOUNTPOINT}/observium/config:/config -v /${CACHE_MOUNTPOINT}/observium/logs:/opt/observium/logs -v /${CACHE_MOUNTPOINT}/observium/rrd:/opt/observium/rrd zuhkov/observium

#Ombi Plex Media Requester
docker run -d --name ombi --restart=always -v /${CACHE_MOUNTPOINT}/ombi:/config -e PGID=${DOCKER_USER} -e PUID=${DOCKER_USER}  -e ${LOCAL_TIMEZONE_CODE} -p 3579:3579 linuxserver/ombi

#Organizr Media Server Organizer
docker run -d --name organizr --restart=always -v /${CACHE_MOUNTPOINT}/organizr:/config -v /${STORAGE_MOUNTPOINT}/Media:/shared -p 800:80 -e PUID=${DOCKER_USER} -e PGID=${DOCKER_USER} -e ${LOCAL_TIMEZONE_CODE} lsiocommunity/organizr

#Pihole DNS Ad Block Utility
docker run -d --name=pihole -p 53:53/tcp -p 53:53/udp -p 8082:80 -v /${CACHE_MOUNTPOINT}/pihole:/etc/pihole -v /${CACHE_MOUNTPOINT}/pihole/dnsmasq.d:/etc/dnsmasq.d -e ServerIP=${CIDR} -e ServerIPv6=${CIDR} -e ${LOCAL_TIMEZONE_CODE} --restart=always diginc/pi-hole:alpine

#Portainer Docker WebUI
docker run -d -p 9000:9000 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v ${CACHE_MOUNTPOINT}/portainer:/data portainer/portainer:latest

#Plex Media Server
docker run -d --name plex --network=host --restart=always -e ${LOCAL_TIMEZONE_CODE} -e PLEX_CLAIM="$PLEX_CLAIM" -v /${CACHE_MOUNTPOINT}/plex:/config -v /${STORAGE_MOUNTPOINT}/${TRANSCODE_PATH}:/transcode -v /${STORAGE_MOUNTPOINT}/${TV_PATH}}:/data/tv -v /${STORAGE_MOUNTPOINT}/${MOVIES_PATH}:/data/movies -v /${STORAGE_MOUNTPOINT}/${OTHER_MEDIA_PATH}:/data/other_media -e PGID=${DOCKER_USER} -e PUID=${DOCKER_USER} plexinc/pms-docker

#Radarr Movie Searcher
docker run -d --name radarr --restart=always -v /${CACHE_MOUNTPOINT}/radarr:/config -v /${STORAGE_MOUNTPOINT}/${COMPLETED_MOVIE_DL_PATH}:/downloads -v /${STORAGE_MOUNTPOINT}/${MOVIES_PATH}:/movies -v /etc/localtime:/etc/localtime:ro -e ${LOCAL_TIMEZONE_CODE} -p 7878:7878 -e PGID=${DOCKER_USER} -e PUID=${DOCKER_USER} linuxserver/radarr

#SABNZBD Newsgroup Downloader
docker run -d --name sabnzbd --restart=always -v /${STORAGE_MOUNTPOINT}/sabnzbd:/config -v /${STORAGE_MOUNTPOINT}/${COMPLETED_MOVIES_DL_PATH}:/${MOVIES_PATH} -v ${STORAGE_MOUNTPOINT}/${COMPLETED_TV_DL_PATH}:/${TV_PATH} -p 8181:8080 -e PUID=${DOCKER_USER} -e PGID=${DOCKER_USER} -e ${LOCAL_TIMEZONE_CODE} linuxserver/sabnzbd

#Sonarr TV Show Searcher
docker run -d --name sonarr --restart=always -v /${CACHE_MOUNTPOINT}/sonarr:/config -v /${STORAGE_MOUNTPOINT}/${COMPLETED_TV_DL_PATH}:/downloads -v /${STORAGE_MOUNTPOINT}/${TV_PATH}:/tv -v /etc/localtime:/etc/localtime:ro -e ${LOCAL_TIMEZONE_CODE} -p 8989:8989 -e PGID=${DOCKER_USER} -e PUID=${DOCKER_USER} linuxserver/sonarr

#Syslog-NG Log Utility
docker run -d  --name=syslog-ng --restart=always --privileged -v /etc/localtime:/etc/localtime:ro -e ${LOCAL_TIMEZONE_CODE} -v /${CACHE_MOUNTPOINT}/syslog-ng:/etc/syslog-ng -v /${CACHE_MOUNTPOINT}/syslog-ng/logs:/var/log -p 514:514 -p 601:601 -p 6514:6514 balabit/syslog-ng:latest

#Tautulli Plex Media Server Stat Utility
docker run -d --name=tautulli --restart=always -v /${CACHE_MOUNTPOINT}/tautulli:/config -v /${CACHE_MOUNTPOINT}/plex/logs:/logs:ro -e PGID=${DOCKER_USER} -e PUID=${DOCKER_USER} -e ${LOCAL_TIMEZONE_CODE} -p 8182:8181 linuxserver/tautulli

#Traefik Docker Reverse Proxy
docker run -d --name=traefik --restart=always -p 8180:8080 -p 80:80 --log-driver json-file --log-opt max-size=10m -v /${CACHE_MOUNTPOINT}/traefik/traefik.toml:/etc/traefik/traefik.toml -v /var/run/docker.sock:/var/run/docker.sock traefik

#Transmission Torrent Client
docker run -d --name transmission --restart=always -v /${CACHE_MOUNTPOINT}/transmission:/config -v /${STORAGE_MOUNTPOINT}/torrents:/downloads -v /${STORAGE_MOUNTPOINT}/torwatch:/watch -e ${LOCAL_TIMEZONE_CODE} -p 9092:9091 -p 51414:51413 -p 51414:51413/udp -e PGID=${DOCKER_USER} -e PUID=${DOCKER_USER} linuxserver/transmission

#Transmission Torrent Client with OpenVPN & Block List
docker run -d --name transmissionvpn --restart=always --cap-add=NET_ADMIN --device=/dev/net/tun -d -v /${CACHE_MOUNTPOINT}/transmissionvpn:/config -v /${STORAGE_MOUNTPOINT}/downloads:/data -v /etc/localtime:/etc/localtime:ro -e ${LOCAL_TIMEZONE_CODE} -e OPENVPN_PROVIDER=${OPENVPN_PROVIDER} -e OPENVPN_CONFIG=${OPVEN_VPN_SERVER} -e OPENVPN_USERNAME=$USER -e OPENVPN_PASSWORD=$PWD -e WEBPROXY_ENABLED=false -e LOCAL_NETWORK=${CIDR} --log-driver json-file --log-opt max-size=10m -p 9091:9091 -p 51413:51413 -p 51413:51413/udp -e PGID=${DOCKER_USER} -e PUID=${DOCKER_USER} -e "OPENVPN_OPTS=--inactive 3600 --ping 10 --ping-exit 60 --mssfix 1460" -e "TRANSMISSION_SCRAPE_PAUSED_TORRENTS_ENABLED=false" -e "TRANSMISSION_BLOCKLIST_ENABLED=true" -e "TRANSMISSION_BLOCKLIST_URL=http://john.bitsurge.net/public/biglist.p2p.gz" -e "TRANSMISSION_DOWNLOAD_QUEUE_ENABLED=false" -e "TRANSMISSION_MAX_PEERS_GLOBAL=5000" -e "TRANSMISSION_PEER_LIMIT_GLOBAL=2000" -e "TRANSMISSION_PEER_LIMIT_PER_TORRENT=500" -e "TRANSMISSION_PORT_FORWARDING_ENABLED=true" -e "TRANSMISSION_RATIO_LIMIT=1" -e "TRANSMISSION_RATIO_LIMIT_ENABLED=true" -e "TRANSMISSION_WATCH_DIR=/data/torwatch" -e "ENABLE_UFW=false" haugene/transmission-openvpn

#Unifi Network Controller
docker run -d --name=unifi --restart=always --net=VLAN-Ext --ip=${UNIFI_IP} -v /etc/localtime:/etc/localtime:ro -v /${CACHE_MOUNTPOINT}/${LETSENCYRPT_CERT_STORAGE}:/usr/lib/unifi/cert -v /etc/localtime:/etc/localtime:ro  -v /${MOUNTPOINT}/unifi/data:/usr/lib/unifi/data -v /${MOUNTPOINT}/unifi/logs:/usr/lib/unifi/logs -e ${LOCAL_TIMEZONE_CODE} -e RUNAS_UID0=false -e RUN_CHOWN=true -e PGID=${DOCKER_GROUP} -e PUID=${DOCKER_USER} -e DEBUG=true goofball222/unifi:sc

#Watchtower Container Updater
docker run -d --name watchtower --rm -v /var/run/docker.sock:/var/run/docker.sock v2tec/watchtower --restart=always --interval 86400
