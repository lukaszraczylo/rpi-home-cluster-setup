# Variables used for barebone kubernetes setup
network_subnet    = "192.168.50"

net_hosts = {
  adguard = "240"
  adguard_catchall = "249"
  traefik = "234"
  torrent_rpc = "245"
}

nfs_storage = {
  general = "/media/nfs"
  torrent = "/mnt/drobo-storage/docker-volumes/torrent"
  adguard = "/mnt/drobo-storage/docker-volumes/adguard"
}

# ENV variable: TRAEFIK_API_KEY sets traefik_api_key
# ENV variable: GH_USER, GH_PAT for authentication with private containers