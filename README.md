# vesta.acme.sh
acme.sh wrapper for vestacp to issue free certificate from Let's Encrypt



#Install:
```
chmod +x vesta.acme.sh

./vesta.acme.sh  install
```


#Add ssl certificate to your site:

```
./vesta.acme.sh  addssl  admin  mydomain.com

```

Once the certificate is generated,  it will be renewed automatically in future.  Just forget it.


#Upgrade acme.sh

```
./vesta.acme.sh  upgrade
```

