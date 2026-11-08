QT += core gui qml testlib
CONFIG += console testcase c++17
CONFIG -= app_bundle
TEMPLATE = app
TARGET = chatclient_test
SOURCES += chatclient_test.cpp
DEFINES += PRAGUS_PROJECT_ROOT=\"\\\"$$clean_path($$PWD/..)\\\"\"
