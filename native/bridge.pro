QT += core qml network gui dbus
TEMPLATE = lib
CONFIG += plugin c++17
TARGET = codexdeskplugin
SOURCES += plugin.cpp dashboardclient.cpp chathistory.cpp
HEADERS += dashboardclient.h chathistory.h
DESTDIR = $$PWD/../package/contents/ui/bridge
