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



addssl() {
  user="$1"
  site="$2"
  
  if [ -z "$site" ] ; then
    echo "Usage: addssl user site"
    return 1
  fi
  
  list="$($VESTA/bin/v-list-web-domains-alias $user | grep "^$site ")"
  if [ -z "$list" ] ; then
    echo "Can not find site: $site"
    return 1
  fi
  
  sans="$(echo $list | cut -d " " -f 2)"
  
  if [ "NULL" = "$sans" ] ; then
    sans=""
  fi
  
  (
    $ACME_ENTRY  --issue  --apache \
    -d "$site" \
    -d "$sans"
  )
  _ret="$?"
  if [ "$_ret" != "0" ] && [ "$_ret" != "2" ] ; then
    echo "Issue cert failed!"
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
    --reloadcmd "apachectl  -k  graceful && service nginx reload"
  )

}



showhelp() {
  echo "Usage: "
  echo "install : install acme.sh"
  echo "upgrade : upgrade acme.sh"
  echo "addssl : addssl acme.sh"

}



if [ -z "$1" ] ; then
  showhelp
else
  "$@"
fi




