#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import psutil
def find_proc_by_name(name):
    for p in psutil.process_iter():
        if p.name() == name:
            return p 
    raise ValueError('no such process: ' + name)
