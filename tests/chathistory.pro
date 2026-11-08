QT = core
CONFIG += console c++17
CONFIG -= app_bundle
TEMPLATE = app
TARGET = chathistory_test
SOURCES += chathistory_test.cpp ../native/chathistory.cpp
HEADERS += ../native/chathistory.h
