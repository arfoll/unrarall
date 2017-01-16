#!/bin/bash
set -e
set -x

if [[ $TRAVIS_OS_NAME == 'osx' ]]; then
  brew update

  # Install unrar, rar and 7z.
  brew install p7zip
  brew cask install rar

  # Install python
  brew install python3
  pip3 install lit==0.5.0 OutputCheck==0.4.1
else
  # Assume Ubuntu
  sudo apt-get install cfv cksfv p7zip-full p7zip-rar unrar rar
  # Note do not do `sudo pip` due to TravisCI using virtualenv
  pip install lit==0.5.0 OutputCheck==0.4.1
fi
