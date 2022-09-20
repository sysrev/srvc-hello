#!/usr/bin/env bash

set -e

./make-spacy-docs.py
python -m spacy train config.cfg --output ./spacy-model
