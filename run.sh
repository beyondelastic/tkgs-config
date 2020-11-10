#!/bin/bash

source config

export REG_CERT=$(echo "$REG_CERT" | base64 -b 0)

# Logging function that will redirect to stderr with timestamp:
logerr() { echo "$(date) ERROR: $@" 1>&2; }
# Logging function that will redirect to stdout with timestamp
loginfo() { echo "$(date) INFO: $@" ;}

function inject_ca()
{
  touch /etc/ssl/certs/regcert.pem
  echo "checking if cert exists"
  if cmp -s "/etc/ssl/certs/regcert.pem.new" "/etc/ssl/certs/regcert.pem"; then
      echo "the cert already exists and has not changed"
  else
      echo "updating the certs"
      mv /etc/ssl/certs/regcert.pem.new /etc/ssl/certs/regcert.pem
      /usr/bin/rehash_ca_certificates.sh
      systemctl restart containerd
      echo "certs updated!"
  fi

}

function run()
{

  #get the machines
  machines=$(kubectl get virtualmachines -A -o json)

  for row in $(echo "${machines}" | jq -r '.items[] | @base64'); do
      _jq() {
      echo ${row} | base64 -d | jq -r ${1}
      }
      loginfo "-------------------"
      #get the namespace
      ns=$(_jq '.metadata.namespace')
      loginfo "namespace: ${ns}"

      #get the cluster name for the machine
      cluster=$(_jq '.metadata.labels."capw.vmware.com/cluster.name"')
      loginfo "cluster: ${cluster}"

      #get the ip for the machine
      ip=$(_jq '.status.vmIp')
      loginfo "ip: ${ip}"

      #get the secret for the machine and create a file
      loginfo "getting ssh key for ${cluster}"
      kubectl get secret ${cluster}-ssh -n ${ns} -o jsonpath="{.data.ssh-privatekey}" | base64 -d > sshkey.pem
      chmod 600 sshkey.pem

      loginfo "attempting ssh to ${ip}"
      ssh -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i sshkey.pem vmware-system-user@${ip} << EOF
      sudo -i
      if grep -q $DNS_SRV /etc/resolv.conf && grep -q $DNS_DOMAIN /etc/resolv.conf
      then
        echo resolve.conf already configured...
      else
        echo "nameserver $DNS_SRV" > /usr/lib/systemd/resolv.conf
        echo "domain $DNS_DOMAIN" >> /usr/lib/systemd/resolv.conf
        rm /etc/resolv.conf
        ln -s /usr/lib/systemd/resolv.conf /etc/resolv.conf        
      fi

      if [[ -z "${REG_CERT}" ]]
      then
        echo no CA cert providied skipping cert injection...
      else
       $(typeset -f inject_ca)
       echo "${REG_CERT}" | base64 -d > /etc/ssl/certs/regcert.pem.new
       inject_ca
      fi



EOF

  if [ $? -eq 0 ] ;
  then
        loginfo "script ran successfully!"
  else
        logerr "There was an error running the script Exiting..."
  fi

loginfo "-------------------"
  done
}

run
rm -f sshkey.pem