QT += core qml network gui dbus
TEMPLATE = lib
CONFIG += plugin c++17
TARGET = codexdeskplugin
SOURCES += plugin.cpp dashboardclient.cpp
HEADERS += dashboardclient.h
DESTDIR = $$PWD/../package/contents/ui/bridge
