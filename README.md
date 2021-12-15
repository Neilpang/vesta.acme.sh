# vesta.acme.sh
    
    `acme.sh` wrapper for vestacp to issue free certificate from Let's Encrypt


#Install:
```
chmod +x vesta.acme.sh
./vesta.acme.sh  install
```


#Add ssl certificate to your site:

```
./vesta.acme.sh addssl admin mydomain.com

```

Once the certificate is generated, it will be renewed automatically in future. Just forget it.

#Upgrade acme.sh

```
./vesta.acme.sh  upgrade
```

#Install CA cert manually
First in VistaCp panel ser `*.<domain.com>` save it.


1) `./vesta.acme.sh CAIssue mydomain.com`
2) `./vesta.acme.sh CARenew user mydomain.com`
2-1) Have error and script tell you what you need recreate on DNS `_acme-chellenge` as TXT with hash.
2-2) Wait 5 mins and run it again.
3) if not installed use this script `./vesta.acme.sh installCert user mydomain.com`


#Install CA cert Auto

Run `./vesta.acme.sh CAAuto user mydomain.com`


### DOCS

VestaCP Shell: [https://github.com/serghey-rodin/vesta/blob/master/bin/v-add-dns-record]