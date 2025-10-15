
# rootless-podman-samba-container


here is a simple rootless podman samba container (base on alpine).
the container use `user map` function of samba to avoid create linux user during running to bypass permission problem.
the users in container are created during creation and your customise user name is mapped to the pre-exist linux users.


there are some limits about the container. 
1. without editing Dockerfil and rebuilding the container, you can help up to 5 users.
2. the container relies on environment variables to define the list of users and their passwords. this can become verbose and difficult to manage if you need a large number of users

you can freely customise your smb.conf but remember some important lines
here is an example which is similar to my usage


smb.conf
```smb.conf
[global]
        # cant be removed, the major setting for implementation
        username map =/etc/samba/usermap.txt #impoartant
        server string = samba
        security = user
        server min protocol = SMB2

        mangled names = no
        mangle prefix = 0

        load printers = no
        printing = bsd
        printcap name = /dev/null
        disable spoolss = yes

[subdir_name]
        #emmm, you can consider like -v subdir_name:/srv/samba/share
        #on the client side, it appears as \\server\subdir_name
        #for more user, maybe /srv/samba/share/user1/ ?
        path = /srv/samba/share

        #must include both of the users in pair of mapped because of unknown reason
        valid users = windows_user_abc samba1 #important
        browseable = yes
        writable = yes
        read only = no

        #inside: root permission. outside: your gid and uid
        force user = root
        force group = root

        create mask = 0660
        directory mask = 0770
```

compose.yml
```compose.yml
services:
  samba:
    image: localhost/samba
    container_name: samba
    network_mode: host
    environment:
      #for multiple users, it should be "abc, abd, add". first would map to samba1, similarly to remains.
      SMB_USERS: "windows_user_abc"
      #similar to password
      SMB_PASSWORDS: "abc"
    volumes:
      - ${PWD}/data:/srv/samba/share
      - ${PWD}/smb.conf:/etc/samba/smb.conf
    restart: always
```
