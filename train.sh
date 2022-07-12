#!/usr/bin/env bash

set -e

./recogito-to-spacy.py
python -m spacy train config.cfg --output ./spacy-model
