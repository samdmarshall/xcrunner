xcrunner
========

dynamic sdk tool lookup


xcrun cannot search the contents of SDKPATH/usr/bin for tools. This utility intercepts an xcrun call and adds the lookup path for the current or selected SDK so that additional tools can be found.
