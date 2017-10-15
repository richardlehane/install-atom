# About

This is a bash script containing the install instructions from the [AtoM install page for Ubuntu Xenial](https://www.accesstomemory.org/en/docs/2.4/admin-manual/installation/linux/ubuntu-xenial/).

You can try it be installing a fresh VM with your favourite cloud provider, then just:

    wget https://raw.githubusercontent.com/richardlehane/install-atom/master/install.sh
    chmod +x install.sh
    sudo ./install.sh

If all goes as planned, you should have a fresh AtoM instance available for configuration at http://localhost.

After install run this to start a gearman worker:

    sudo systemctl start atom-worker

## Defaults 

You can change the database host (defaults to localhost), root and atom passes (both default to dummy passes) by including as environment variables before running script.

If you provide a DB host, then the install script will just install a mysql client (5.7). Otherwise it will install a percona-server (5.6) running at localhost.

E.g.:

    wget https://raw.githubusercontent.com/richardlehane/install-atom/master/install.sh
    chmod +x install.sh
    export DB_HOST=32.141.56.213
    export ROOT_PASS=fhuih032unf
    export ATOM_PASS=fij93hohfl8
    sudo ./install.sh > install_log 2> install_err
    sudo systemctl start atom-worker