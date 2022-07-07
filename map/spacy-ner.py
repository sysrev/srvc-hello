#!/usr/bin/env python

import json, math, os, spacy, time, uuid
from pathlib import Path
# make the factory work
from scripts.rel_pipe import make_relation_extractor, score_relations
# make the config work
from scripts.rel_model import create_relation_model, create_classification_layer, create_instances, create_tensors

def get_answers(event, label, reviewer):
    doc = nlp(event['data']['abstract'])

    answers = []
    for ent in doc.ents:
        anno = {
            'chunk_end': ent.end_char,
            'chunk_start': ent.start_char,
            'chunk_text': str(ent),
            'id': str(uuid.uuid4()),
            'label': [ent.label_],
            'type': 'TAG'
        }
        answer = {
            'data': {
                'answer': anno,
                'document': event['hash'],
                'label': label['hash'],
                'reviewer': reviewer,
                'timestamp': math.floor(time.time())
            },
            'type': 'label-answer'
        }
        answers.append(answer)
    return answers

## Load pipeline
trained_pipeline= Path('model/model_tok2vec')
nlp = spacy.load(trained_pipeline)

config = json.load(open(os.environ['SR_CONFIG']))
labels = config['current_labels']
annotation_label = labels[0]

with open(os.environ['SR_INPUT']) as sr_input, open(os.environ['SR_OUTPUT'], 'a') as sr_output:
    for line in sr_input:
        sr_output.write(line)
        sr_output.flush()
        event = json.loads(line)
        if event['type'] == 'document' and event['data'].get('abstract'):
            for answer in get_answers(event, annotation_label, config['reviewer']):
                sr_output.write(json.dumps(answer))
                sr_output.flush()
