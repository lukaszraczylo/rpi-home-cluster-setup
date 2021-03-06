# Variables used for barebone kubernetes setup
network_subnet    = "192.168.50"
rtorrent_rpc_host = "245"
adguard_host      = "240"
adguard_catchall_host  = "249"

nfs_torrent_path = "/mnt/drobo-storage/docker-volumes/torrent"
nfs_adguard_path = "/mnt/drobo-storage/docker-volumes/adguard"

# ENV variable: TRAEFIK_API_KEY sets traefik_api_key
# ENV variable: GH_USER, GH_PAT for authentication with private containers