# tkgs-config
This script helps to configure DNS and self-signed certificates on TKGS clusters for none NSX setups. For NSX setups, please refer to https://github.com/warroyo/tkgs-proxy-inject. 

The script can be executed locally, just make sure you are logged in to the Supervisor Cluster with administrator@vsphere.local and your kubectl context is set to the default cluster context. Edit the config file with DNS and certificate values of your environment and execute the script. 

Disclaimer: This is not tested or supported by VMware. Use it at your own risk. 

