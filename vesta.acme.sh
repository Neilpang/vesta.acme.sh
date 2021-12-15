#!/usr/bin/env sh

VESTA_ENTRY="vesta.acme.sh"
ACME_HOME="$HOME/.acme.sh"
ACME_ENTRY="$HOME/.acme.sh/acme.sh"

if [ -z "$VESTA" ] ; then
  VESTA="/usr/local/vesta"
  export VESTA
fi

install() {
  if ! (curl https://get.acme.sh | sh) ; then
    echo "Install error."
    return 1
  fi
}

upgrade() {
  install
}

## MANUAL PART ---------------------

installCert() {
  user="$1"
  site="$2"

  if [ -z "$user" ] || [ -z "$site" ] ; then
    echo "Run the script like this\n"
    echo "./vesta.acme.sh installCert user mydomain.com"
    return 1
  fi

  tempcer="tempcer"
  mkdir "$tempcer"
  cp "$ACME_HOME/$site/$site.key" "$tempcer/$site.key"
  cp "$ACME_HOME/$site/$site.cer" "$tempcer/$site.crt"
  cp "$ACME_HOME/$site/ca.cer"    "$tempcer/$site.ca"

  $VESTA/bin/v-add-web-domain-ssl $user $site "$tempcer"
  rm -rf "$tempcer"
  
  (
    $ACME_ENTRY  --installcert \
    -d $site \
    --certpath  /home/$user/conf/web/ssl.$site.crt \
    --keypath   /home/$user/conf/web/ssl.$site.key \
    --capath    /home/$user/conf/web/ssl.$site.ca \
    --fullchainpath  /home/$user/conf/web/ssl.$site.pem \
    --reloadcmd "service nginx force-reload && apachectl graceful"
  )
}

#parse domain
CAIssue() {
  site="$"

  if [ -z "$site" ] ; then
    echo "Run the script like this\n"
    echo "./vesta.acme.sh CAIssue mydomain.com"
    return 1
  fi

  ($ACME_ENTRY --issue -d $site -d *.$site --dns --force --yes-I-know-dns-manual-mode-enough-go-ahead-please --debug)
}

CARenew() {
  user="$1"
  site="$2"

  if [ -z "$user" ] || [ -z "$site" ] ; then
    echo "Run the script like this\n"
    echo "./vesta.acme.sh CARenew user mydomain.com"
    return 1
  fi

  ($ACME_ENTRY --renew  -d "$site" -d "*.$site" --dns --force --yes-I-know-dns-manual-mode-enough-go-ahead-please)
 
  _ret="$?"
  if [ "$_ret" != "0" ] && [ "$_ret" != "2" ] ; then
    echo "Issue cert failed!"
    return 1
  fi
    
  installCert $user $site
}

## MANUAL PART ---------------------

## AUTO PART ---------------------

CAAuto() {
  user="$1"
  site="$2"

  if [ -z "$user" ] || [ -z "$site" ] ; then
    echo "Run the script like this\n"
    echo "./vesta.acme.sh CAAuto user mydomain.com"
    return 1
  fi

  #check dns for challenge
  CH=$(/usr/local/vesta/bin/v-list-dns-records $user $site | "grep _acme-challenge" | awk '{ print $1 }' )

  if [ CH ] ; then
    echo "First cleaning old challenges"

    for rline in $CH; do
      /usr/local/vesta/bin/v-delete-dns-record $user $site $rline
    done

    echo "Done."
  fi

  echo "Check domain aliases, looking for *.domain.com"

  ALIASES=$(/usr/local/vesta/bin/v-list-web-domain $user $domain | grep "*")

  if [ ! ALIASES ]; then
    echo "Adding * aliases"
    #* add aliases 
    /usr/local/vesta/bin/v-add-web-domain-alias $user $site *.$site
  fi

  STEPONE=$(CAIssue $site | grep "txt='" | awk -F= '{ print $2 }' | sed "s/[']//g") 

  if [ ! $STEPONE ] ; then
    echo "Run it again."
    return 1
  fi

  echo "Backup you DNS config"
  cp /home/$user/conf/dns/$site.db /home/$user/conf/dns/$site.db_back

  echo "Get challenge hash adding to your DNS zone."

  #add to dns
  for line in $O; do
    echo -e "_acme-challenge\t14400\tIN\tTXT\t\"$line\"" >> /home/$user/conf/dns/$site.db 
  done

  /usr/local/vesta/bin/v-insert-dns-records $user $site /home/$user/conf/dns/$site.db

  echo "Ok. DNS Zone applyed, now wait 2 mins for propagation. And continue with the process..."
  wait 120

  FINALSTEP=$(CARenew $user $site | grep "BEGIN CERTIFICATE")

  #TODO: cehck this part for 
  if [ $FINALSTEP ]; then
    echo "Installing Cert"
    installCert $user $site
    return 1
  fi
}

## AUTO PART ---------------------

addssl() {
  user="$1"
  site="$2"
  noAlias="$3"
  
  if [ -z "$site" ] ; then
    echo "Usage: addssl user site"
    return 1
  fi
  
  if [ $noAlias = "NULL" ] ; then  

    list=$($VESTA/bin/v-list-web-domain $user "$site" | grep '^ALIAS' | cut -d: -f 2)
    if [ -z "$list" ] ; then
      echo "Can not find site: $site"
      return 1
    fi
    
    if [ "NULL" = "$list" ] ; then
      sans=""
    else
      sans="$(echo $list | tr ' ' ,)"
    fi
    (
      $ACME_ENTRY --issue \
      -w /home/$user/web/$site/public_html \
      -d "$site" \
      -d "$sans"
    )
  else
    sans=""
    (
      $ACME_ENTRY --issue \
      -w /home/$user/web/$site/public_html \
      -d "$site" \
      -d "*.$site" \
      --force
    )
  fi
  
  _ret="$?"
  if [ "$_ret" != "0" ] && [ "$_ret" != "2" ] ; then
    echo "Issue cert failed!"
    return 1
  fi
    
  installCert $user $site
}

showhelp() {
  echo "Usage: "
  echo "install : install acme.sh"
  echo "upgrade : upgrade acme.sh"
  echo "addssl : add ssl to a plain site"
  echo "\n-----\n"

  echo "First step :"
  echo "CAIssue <domain> : get acme challenge is needed to manually add txt record"
  echo "Wait 5 - 10 minutes for apply dns"
  
  echo "Second step :"
  echo "CARenew <user> <domain> : get acme ssl cer add to a plain site"
  echo "installCert <user> <domain> : move gen cert to domain folder and apply"

  echo "\n-----\n"

  echo "MANUAL CA"
  echo "sample ./vesta.acme.sh CAIssue <domain.com>"
  echo "sample ./vesta.acme.sh CARenew <user> <domain.com>"
  echo "sample ./vesta.acme.sh installCert <user> <domain.com>"

  echo "ATUO CA"
  echo "sample ./vesta.acme.sh CAAuto <user> <domain.com>"
}

if [ -z "$1" ] ; then
  showhelp
else
  "$@"
fi