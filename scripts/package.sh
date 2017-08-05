#!/usr/bin/env bash

###########################################################################
# Packaging script which creates debian and RPM packages for influxdb-sqlserver.
# Requirements: 
# - GOPATH must be set
# - 'fpm' must be on the path
#
#    https://github.com/zensqlmonitor/influxdb-sqlserver
#
# Packaging process: to install a build, simply execute:
#
#    package.sh
#
# The script will automatically determined the version number from git using
# `git describe --always --tags`
#

INSTALL_ROOT_DIR=/opt/influxdb-sqlserver
CONFIG_ROOT_DIR=/etc/influxdb-sqlserver
CONFIG_FILE=influxdb-sqlserver.conf
PROG_LOG_DIR=/var/log/influxdb-sqlserver
SQLSCRIPTS_DIR_SOURCE=sqlscripts/
SQLSCRIPTS_DIR=/usr/local/influxdb-sqlserver/sqlscripts/
LOGROTATE_DIR=/etc/logrotate.d/

SCRIPTS_DIR=/usr/lib/influxdb-sqlserver/scripts/
LOGROTATE_CONFIGURATION=scripts/influxdb-sqlserver
INITD_SCRIPT=scripts/init.sh
SYSTEMD_SCRIPT=scripts/influxdb-sqlserver.service

TMP_WORK_DIR=$(mktemp -d)
WORK_DIR=''
POST_INSTALL_PATH=$(mktemp)
ARCH=$(uname -i)
LICENSE=MIT
URL=https://github.com/zensqlmonitor/influxdb-sqlserver
MAINTAINER=sqlzen@hotmail.com
VENDOR=sqlzenmonitor
DESCRIPTION="Collect Microsoft SQL Server metrics for reporting into InfluxDB"
PKG_DEPS=(coreutils)
GO_VERSION="go1.8"
GOPATH_INSTALL=
BINS=(
    influxdb-sqlserver
    )

###########################################################################
# Helper functions.

# usage prints simple usage information.
usage() {
    echo -e "$0\n"
    cleanup_exit $1
}

# make_dir_tree creates the directory structure within the packages.
make_dir_tree() {
    work_dir=$1
	version=$2
    mkdir -p $work_dir/$INSTALL_ROOT_DIR/versions/$version/scripts
    if [ $? -ne 0 ]; then
        echo "Failed to create installation directory -- aborting."
        cleanup_exit 1
    fi
    mkdir -p $work_dir/$CONFIG_ROOT_DIR
    if [ $? -ne 0 ]; then
        echo "Failed to create configuration directory -- aborting."
        cleanup_exit 1
    fi
    mkdir -p $work_dir/$PROG_LOG_DIR
    if [ $? -ne 0 ]; then
        echo "Failed to create log directory -- aborting."
        cleanup_exit 1
    fi
    mkdir -p $work_dir/$SQLSCRIPTS_DIR
    if [ $? -ne 0 ]; then
        echo "Failed to create sql scripts directory -- aborting."
        cleanup_exit 1
    fi
    mkdir -p $work_dir/$LOGROTATE_DIR
    if [ $? -ne 0 ]; then
        echo "Failed to create log rotate temporary directory -- aborting."
        cleanup_exit 1
    fi	
	
}

# cleanup_exit removes all resources created during the process and exits with
# the supplied returned code.
cleanup_exit() {
    rm -r $TMP_WORK_DIR
    rm $POST_INSTALL_PATH
    exit $1
}

# check_gopath sanity checks the value of the GOPATH env variable, and determines
# the path where build artifacts are installed. GOPATH may be a colon-delimited
# list of directories.
check_gopath() {
    [ -z "$GOPATH" ] && echo "GOPATH is not set." && cleanup_exit 1
    GOPATH_INSTALL=`echo $GOPATH | cut -d ':' -f 1`
    [ ! -d "$GOPATH_INSTALL" ] && echo "GOPATH_INSTALL is not a directory." && cleanup_exit 1
    echo "GOPATH ($GOPATH) looks sane, using $GOPATH_INSTALL for installation."
}

# check_clean_tree ensures that no source file is locally modified.
check_clean_tree() {
    modified=$(git ls-files --modified | wc -l)
    if [ $modified -ne 0 ]; then
        echo "The source tree is not clean -- aborting."
        cleanup_exit 1
    fi
    echo "Git tree is clean."
}

# do_build builds the code. The version and commit must be passed in.
do_build() {
    version=$1
    commit=`git rev-parse HEAD`
    if [ $? -ne 0 ]; then
        echo "Unable to retrieve current commit -- aborting"
        cleanup_exit 1
    fi

    for b in ${BINS[*]}; do
        rm -f $GOPATH_INSTALL/bin/$b
    done

    #gdm restore
	echo "Building..."
    go install -ldflags="-X main.Version=$version" ./...
    if [ $? -ne 0 ]; then
        echo "Build failed, unable to create package -- aborting"
        cleanup_exit 1
    fi
	
	# copy configuration file
	echo "Copying configuration file..."
	cp ././$CONFIG_FILE $GOPATH_INSTALL/bin
	if [ $? -ne 0 ]; then
        echo "Build failed, unable to copy configuration file -- aborting"
        cleanup_exit 1
    fi
	
	echo "Replacing parameters in configuration file..."
	sed -i 's|logfile="collectsql.log"|logfile="/var/log/influxdb-sqlserver/collectsql.log"|g' $GOPATH_INSTALL/bin/$CONFIG_FILE
	if [ $? -ne 0 ]; then
        echo "Build failed, unable to update configuration file -- aborting"
        cleanup_exit 1
    fi

    echo "Build completed successfully."
}

# generate_postinstall_script creates the post-install script for the
# package. It must be passed the version.
generate_postinstall_script() {
    version=$1
    cat  <<EOF >$POST_INSTALL_PATH
#!/bin/sh
rm -f $INSTALL_ROOT_DIR/influxdb-sqlserver
rm -f $INSTALL_ROOT_DIR/init.sh
ln -sfn $INSTALL_ROOT_DIR/versions/$version/influxdb-sqlserver $INSTALL_ROOT_DIR/influxdb-sqlserver
if ! id influxdb-sqlserver >/dev/null 2>&1; then
    useradd --help 2>&1| grep -- --system > /dev/null 2>&1
    old_useradd=\$?
    if [ \$old_useradd -eq 0 ]
    then
        useradd --system -U -M influxdb-sqlserver
    else
        groupadd influxdb-sqlserver && useradd -M -g influxdb-sqlserver influxdb-sqlserver
    fi
fi
# Systemd
if which systemctl > /dev/null 2>&1 ; then
    cp $INSTALL_ROOT_DIR/versions/$version/scripts/influxdb-sqlserver.service \
        /lib/systemd/system/influxdb-sqlserver.service
    systemctl enable influxdb-sqlserver
    #  restart on upgrade of package
    if [ "$#" -eq 2 ]; then
        systemctl restart influxdb-sqlserver
    fi
# Sysv
else
    ln -sfn $INSTALL_ROOT_DIR/versions/$version/scripts/init.sh \
        $INSTALL_ROOT_DIR/init.sh
    rm -f /etc/init.d/influxdb-sqlserver
    ln -sfn $INSTALL_ROOT_DIR/init.sh /etc/init.d/influxdb-sqlserver
    chmod +x /etc/init.d/influxdb-sqlserver
    # update-rc.d sysv service:
    if which update-rc.d > /dev/null 2>&1 ; then
        update-rc.d -f influxdb-sqlserver remove
        update-rc.d influxdb-sqlserver defaults
    # CentOS-style sysv:
    else
        chkconfig --add influxdb-sqlserver
    fi
    #  restart on upgrade of package
    if [ "$#" -eq 2 ]; then
        /etc/init.d/influxdb-sqlserver restart
    fi
    mkdir -p $influxdb-sqlserver_LOG_DIR
    chown -R -L influxdb-sqlserver:influxdb-sqlserver $influxdb-sqlserver_LOG_DIR
fi
chown -R -L influxdb-sqlserver:influxdb-sqlserver $INSTALL_ROOT_DIR
chmod -R a+rX $INSTALL_ROOT_DIR
EOF
    echo "Post-install script created successfully at $POST_INSTALL_PATH"
}

###########################################################################
# Start the Packaging process.

if [ "$1" == "-h" ]; then
    usage 0
elif [ "$1" == "" ]; then
    VERSION=`git describe --always --tags | tr -d v`
else
    VERSION="$1"
fi

cd `git rev-parse --show-toplevel`
echo -e "\nStarting packaging process, version: $VERSION\n"

check_gopath
do_build  $VERSION
make_dir_tree $TMP_WORK_DIR $VERSION

###########################################################################
# Copy the assets to the installation directories.

for b in ${BINS[*]}; do
    cp $GOPATH_INSTALL/bin/$b $TMP_WORK_DIR/$INSTALL_ROOT_DIR/versions/$VERSION
    if [ $? -ne 0 ]; then
        echo "Failed to copy binaries to packaging directory -- aborting."
        cleanup_exit 1
    fi
done
echo "${BINS[*]} copied to $TMP_WORK_DIR$INSTALL_ROOT_DIR/versions/$VERSION"

cp $GOPATH_INSTALL/bin/$CONFIG_FILE $TMP_WORK_DIR/$CONFIG_ROOT_DIR
if [ $? -ne 0 ]; then
    echo "Failed to copy configuration file to packaging directory -- aborting."
    cleanup_exit 1
fi
echo "$CONFIG_FILE copied to $TMP_WORK_DIR$CONFIG_ROOT_DIR"

cp -R $SQLSCRIPTS_DIR_SOURCE/* $TMP_WORK_DIR/$SQLSCRIPTS_DIR   
if [ $? -ne 0 ]; then
    echo "Failed to copy T-SQL scripts to packaging directory -- aborting."
    cleanup_exit 1
fi
echo "T-SQL scripts copied to $TMP_WORK_DIR$SQLSCRIPTS_DIR"

cp $SYSTEMD_SCRIPT $TMP_WORK_DIR/$INSTALL_ROOT_DIR/versions/$VERSION/scripts
if [ $? -ne 0 ]; then
    echo "Failed to copy systemd file to packaging directory -- aborting."
    cleanup_exit 1
fi
echo "$SYSTEMD_SCRIPT copied to $TMP_WORK_DIR/$INSTALL_ROOT_DIR/scripts"

cp $INITD_SCRIPT $TMP_WORK_DIR/$INSTALL_ROOT_DIR/versions/$VERSION/scripts
if [ $? -ne 0 ]; then
    echo "Failed to copy init.d script to packaging directory -- aborting."
    cleanup_exit 1
fi
echo "$INITD_SCRIPT copied to $TMP_WORK_DIR/$INSTALL_ROOT_DIR/versions/$VERSION/scripts"

cp $LOGROTATE_CONFIGURATION $TMP_WORK_DIR/$LOGROTATE_DIR/influxdb-sqlserver
if [ $? -ne 0 ]; then
    echo "Failed to copy $LOGROTATE_CONFIGURATION to packaging directory -- aborting."
    cleanup_exit 1
fi
echo "$LOGROTATE_CONFIGURATION copied to $TMP_WORK_DIR/$LOGROTATE_DIR/influxdb-sqlserver"

generate_postinstall_script $VERSION

###########################################################################
# Create the actual packages.

if [ "$CIRCLE_BRANCH" == "" ]; then
    echo -n "Commence creation of $ARCH packages, version $VERSION? [Y/n] "
    read response
    response=`echo $response | tr 'A-Z' 'a-z'`
    if [ "x$response" == "xn" ]; then
        echo "Packaging aborted."
        cleanup_exit 1
    fi
fi

if [ $ARCH == "i386" ]; then
    rpm_package=influxdb-sqlserver-$VERSION-1.i686.rpm
    debian_package=influxdb-sqlserver_${VERSION}_i686.deb
    deb_args="-a i686"
    rpm_args="setarch i686"
elif [ $ARCH == "arm" ]; then
    rpm_package=influxdb-sqlserver-$VERSION-1.armel.rpm
    debian_package=influxdb-sqlserver_${VERSION}_armel.deb
else
    rpm_package=influxdb-sqlserver-$VERSION-1.x86_64.rpm
    debian_package=influxdb-sqlserver_${VERSION}_amd64.deb
fi

COMMON_FPM_ARGS="-C $TMP_WORK_DIR --vendor $VENDOR --url $URL --license $LICENSE \
                --maintainer $MAINTAINER --after-install $POST_INSTALL_PATH \
                --name influxdb-sqlserver --provides influxdb-sqlserver --version $VERSION \
				--config-files $CONFIG_ROOT_DIR --package ./$rpm_package"
        
$rpm_args fpm -s dir -t rpm --description "$DESCRIPTION" $COMMON_FPM_ARGS
if [ $? -ne 0 ]; then
    echo "Failed to create RPM package -- aborting."
    cleanup_exit 1
fi
echo "RPM package created successfully."

COMMON_FPM_ARGS="-C $TMP_WORK_DIR --vendor $VENDOR --url $URL --license $LICENSE \
                --maintainer $MAINTAINER --after-install $POST_INSTALL_PATH \
                --name influxdb-zabbix --provides influxdb-zabbix --version $VERSION \
				        --config-files $CONFIG_ROOT_DIR --deb-no-default-config-files --package ./$debian_package"
                                                        
fpm -s dir -t deb $deb_args --description "$DESCRIPTION" $COMMON_FPM_ARGS
if [ $? -ne 0 ]; then
    echo "Failed to create Debian package -- aborting."
    cleanup_exit 1
fi
echo "Debian package created successfully."

###########################################################################
# All done.

echo -e "\nPackaging process complete."
cleanup_exit 0