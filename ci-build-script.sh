# build debian source package in CI

# check for parameters
if [ "x${SRC_VER}" = "x" -o "x${SRC_ARCHIVE}" = "x" -o "x${SRC_DESTDIR}" = "x" -o "x${PREV_VER}" = "x" ];then
echo "Missing parameters"
exit 1
fi

# ensure Debian suite is set
if [ "x${1}" = "x" ]; then
DEBIAN_SUITE=sid
else
DEBIAN_SUITE="${1}"
fi

# show parameters
echo DEBIAN_SUITE=${DEBIAN_SUITE}
echo SRC_VER=${SRC_VER}
echo SRC_ARCHIVE=${SRC_ARCHIVE}
echo SRC_DESTDIR=${SRC_DESTDIR}
echo PREV_VER=${PREV_VER}

SCPUSER=netsurf
SCPBASE=/srv/ci.netsurf-browser.org/html
SCPSRV=ci.netsurf-browser.org

# if parameters file is present from previous run use it for previous debian version
if [ -f PARAMETERS ];then
  PREV_DEB_VER=$(sed -ne '/^[ ]*DEB_VER[ ]*=[ ]*.*/ { s#^[ ]*DEB_VER[ ]*=[ ]*##; p; }' PARAMETERS)
  # ensure any stale parameters file is removed
  rm -f PARAMETERS
else
  PREV_DEB_VER="${PREV_VER}-1"
fi

DEB_VER="${SRC_VER}-1"
DEB_SRC_DESTDIR=${SCPBASE}/debian/${DEBIAN_SUITE}/source


# copy the source tar here
if [ ! -f netsurf_${SRC_VER}.orig.tar.gz ];then
scp ${SCPUSER}@ci.netsurf-browser.org:${SRC_DESTDIR}/${SRC_ARCHIVE} netsurf_${SRC_VER}.orig.tar.gz
fi

# remove any existing source
if [ -d netsurf-${SRC_VER} ];then
rm -rf netsurf-${SRC_VER}
fi

# unpack source tar and ensure the directory name is correct
tar -axf netsurf_${SRC_VER}.orig.tar.gz
mv netsurf-all-${SRC_VER} netsurf-${SRC_VER}

# get the base debian packaging
(cd debian && git archive --prefix=debian/ --format=tar HEAD) | tar -xC netsurf-${SRC_VER}

# update version
(cd netsurf-${SRC_VER} && dch -b --newversion "${DEB_VER}" "CI build")

# build source deb
(cd netsurf-${SRC_VER} && debuild -S -us -uc -nc -Zxz)

# copy source deb to published area
scp netsurf_${DEB_VER}.dsc netsurf_${DEB_VER}.debian.tar.xz netsurf_${SRC_VER}.orig.tar.gz ${SCPUSER}@${SCPSRV}:${DEB_SRC_DESTDIR}

# remove old versions
ssh ${SCPUSER}@${SCPSRV} "rm -f ${DEB_SRC_DESTDIR}/netsurf_${PREV_DEB_VER}.dsc ${DEB_SRC_DESTDIR}/netsurf_${PREV_DEB_VER}.debian.tar.xz ${DEB_SRC_DESTDIR}/netsurf_${PREV_VER}.orig.tar.gz"

#cleanup
rm -f netsurf_${DEB_VER}.dsc netsurf_${DEB_VER}.debian.tar.xz netsurf_${SRC_VER}.orig.tar.gz
rm -rf netsurf-${SRC_VER}

# setup trigger parameters for package builds
echo "SRC_VER=${SRC_VER}" > PARAMETERS
echo "PREV_VER=${PREV_VER}" >> PARAMETERS
echo "DEB_VER=${DEB_VER}" >> PARAMETERS
echo "PREV_DEB_VER=${PREV_DEB_VER}" >> PARAMETERS
echo "SRC_ARCHIVE=${SRC_ARCHIVE}" >>PARAMETERS
echo "SRC_DESTDIR=${SRC_DESTDIR}" >>PARAMETERS
echo "DEB_SRC_DESTDIR=${DEB_SRC_DESTDIR}" >>PARAMETERS

