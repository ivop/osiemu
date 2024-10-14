FROM debian:bullseye

ENV LC_ALL C
ENV LANG ${LC_ALL}

RUN set -x \
  && apt-get update -y \
  && apt-get upgrade -y \
  && apt-get install -y git make gcc g++ qtbase5-dev qt5-qmake \
        qtbase5-dev-tools libsdl2-dev libsdl2-image-dev cmake wget \
        vim patchelf \
  && apt-get clean \
  && sync

RUN git clone --depth=1 https://github.com/probonopd/linuxdeployqt
RUN cd linuxdeployqt && mkdir build && cd build && cmake .. && make -j`nproc`

RUN git clone --depth=1 --recurse-submodules https://github.com/ivop/osiemu
RUN cd osiemu && deploy/deploy.sh

CMD /bin/bash -l
