#!/usr/bin/env python

import json, spacy

from spacy.tokens import DocBin

nlp = spacy.blank('en')

def build_spacy_doc(events, event):
    recogito = event['data']['answer']
    tags = filter(lambda x: x['type'] == 'TAG', recogito)
    tags = sorted(tags, key = lambda x: x['chunk_start'])
    doc = nlp(events[event['data']['document']]['data']['abstract'])

    tit = iter(doc)
    tkn = next(tit)
    for ann in tags:
        start = ann['chunk_start'] - 16 # Correct bad data from R
        if ann['type'] == 'TAG':
            while tkn.idx < start:
                tkn = next(tit)
            if tkn.idx == start and tkn.text == ann['chunk_text']:
                # mismatch: spacy only has one tag, but recogito allows many
                tkn.tag_ = ann['label'][0]
            elif tkn.idx > start:
                raise Exception('Failed to match recogito chunk to spacy token')

    return doc

with open('sink.jsonl', 'rt') as sink:
    doc_bin = DocBin()
    events = {}
    for line in sink:
        event = json.loads(line)
        events[event['hash']] = event
        if event['type'] == 'label-answer':
            doc_bin.add(build_spacy_doc(events, event))

doc_bin.to_disk("./train.spacy")
