## unrarall

[![Build Status](https://travis-ci.org/arfoll/unrarall.svg?branch=master)](https://travis-ci.org/arfoll/unrarall)

unrarall attemps to extract all rar files in a given directory (and its sub-directories) and once successfully extracted remove all the rar files to cleanup (you must pass --clean= for this to happen and use the rar hook). Other unwanted files can be removed by the use of the other available hooks (see the list shown in --help ). It is meant to be more error proof and quicker than cleaning by hand.

If there's something you would liked removed by unrarall then you can implement your own hook (See HACKING).

## INSTALL
1. You just need to make sure you set execute permission on the script. This can be done using the following command:

chmod u+x unrarall

2. Place the script wherever you want it and rename it to whatever you want. I prefer unrarall.

## BUGS

See TODO

## USAGE

Run unrarall -h to get the help

Enjoy.

## ACKNOWLEDGEMENTS

Name and idea comes from "jeremy" see - http://askubuntu.com/questions/7059/script-app-to-unrar-files-and-only-delete-the-archives-which-were-sucessfully

[![Analytics](https://ga-beacon.appspot.com/UA-11959363-2/arfoll/unrarall)](https://github.com/igrigorik/ga-beacon)


[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/arfoll/unrarall/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

