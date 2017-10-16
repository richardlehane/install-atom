# About

This is a bash script containing the install instructions from the [AtoM install page for Ubuntu Xenial](https://www.accesstomemory.org/en/docs/2.4/admin-manual/installation/linux/ubuntu-xenial/).

## Simple, all-in-one install

To do an all-in-one install on a fresh VM provisioned with your favourite cloud provider (e.g. a Xenial image from Google Compute Engine) just:

    wget https://raw.githubusercontent.com/richardlehane/install-atom/master/install.sh
    chmod +x install.sh
    sudo ./install.sh

If all goes as planned, you should have a fresh AtoM instance available for configuration at http://localhost.

If you're using the default passwords (see below), enter "atom" as the Databse user and "atom-pass" as the Database password on the Database setup screen.

After completing the AtoM configuration process, run this final command to start a gearman worker (which will run jobs like imports for you):

    sudo systemctl start atom-worker

## Default passwords 

You can change the default root and atom user passwords ("root-pass" and "atom-pass" respectively) by including as environment variables before running script.

E.g.

    wget https://raw.githubusercontent.com/richardlehane/install-atom/master/install.sh
    chmod +x install.sh
    export ROOT_PASS=fhuih032unf
    export ATOM_PASS=fij93hohfl8
    sudo ./install.sh > install_log 2> install_err
    
(complete the AtoM configuration proecess by going to http://localhost)

    sudo systemctl start atom-worker

## Two server setup: database server and application server

If you provide a DB_HOST environment variable, then the install script will skip the database install and setup steps. This allows you to have a two machine setup: a dedicated MySQL database server + an application server (running Nginx, PHP, Elastic Search and AtoM). This would allow for example the use of Google SQL for the database (pick MySQL version 5.6 when setting it up) and Google Compute Engine for the application server.

To get this working you will need to configure the database server before installing AtoM. This involves setting up an "atom" database on the database server and adding an "atom" user. You can do this with these SQL commands:

    CREATE DATABASE atom CHARACTER SET utf8 COLLATE utf8_unicode_ci;
    GRANT ALL ON atom.* TO 'atom'@'%' IDENTIFIED BY '$ATOM_PASS';

(If you are using Google SQL then you can enter these commands by using the gcloud command line tool: `gcloud sql connect name-of-db-instance` will give you a mysql> prompt where you can enter the above SQL command. Alternatively, you could use the GUI in the Google SQL console to add the user and database manually. Finally, in order for your Google Compute Engine application server to connect to the database server you will need to add the static IP of that machine to the "Authorisation" list in the Google SQL console. To get a static IP for your Google Compute application server go to VPC Network -> External IP Addresses page and assign one).

Having done all that, you can setup the application server just by giving it a DB_HOST environment variable (which can have any value - just needs to be there).

E.g.:

    wget https://raw.githubusercontent.com/richardlehane/install-atom/master/install.sh
    chmod +x install.sh
    export DB_HOST=blablabla
    sudo ./install.sh > install_log 2> install_err

(complete the AtoM configuration proecess by going to http://localhost)

    sudo systemctl start atom-worker