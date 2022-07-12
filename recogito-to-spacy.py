#!/usr/bin/env python

import json, spacy

from spacy.tokens import DocBin, Span

nlp = spacy.blank('en')

def type_eq(s):
    return lambda x: x['type'] == s

def build_spacy_doc(events, event):
    # Convert WebAnnotation to spacy Doc
    doc = nlp(events[event['data']['document']]['data']['abstract'])

    ents = []
    for webann in event['data']['answer']:
        tagging = filter(lambda x: x['purpose'] == 'tagging', webann['body'])
        tag = next(tagging)['value']

        pos = next(filter(type_eq('TextPositionSelector'), webann['target']['selector']))
        span = doc.char_span(pos['start'], pos['end'], label=tag, alignment_mode="expand")
        ents.append(span)

    doc.set_ents(ents)
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
