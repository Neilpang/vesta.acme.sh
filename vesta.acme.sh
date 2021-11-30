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

CAIssue() {
  ($ACME_ENTRY --issue -d $1 -d *.$1 --dns --force --yes-I-know-dns-manual-mode-enough-go-ahead-please --debug)
}

CARenew() {
  user="$1"
  site="$2"
  
  if [ -z "$site" ] ; then
    echo "Usage: addssl user site"
    return 1
  fi

  ($ACME_ENTRY --renew  -d "$site" -d "*.$site" --dns --force --yes-I-know-dns-manual-mode-enough-go-ahead-please)
 
  _ret="$?"
  if [ "$_ret" != "0" ] && [ "$_ret" != "2" ] ; then
    echo "Issue cert failed!"
    return 1
  fi
    
  installCert
}

installCert() {
  user="$1"
  site="$2"

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
    
  installCert

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

  echo "sample ./vesta.acme.sh CAIssue <domain.com>"
  echo "sample ./vesta.acme.sh CARenew <user> <domain.com>"
}

if [ -z "$1" ] ; then
  showhelp
else
  "$@"
fi