FROM ubuntu:22.04

# Install
RUN apt update -y
RUN apt install -y python3-pip cksfv p7zip-full p7zip-rar unrar rar git file
RUN python3 -m pip install --upgrade pip
RUN python3 -m pip install lit OutputCheck cfv

# Build Preparation
RUN mkdir -p /src/
RUN mkdir -p /src/build/

# Build
WORKDIR /src/
COPY . /src/
RUN cd /src

# Run Tests
RUN git clone http://github.com/arfoll/unrarall.git unraralltest/
RUN ./unraralltest/tests/run.sh
