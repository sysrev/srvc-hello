#!/usr/bin/env python

import json, math, os, spacy, time, uuid

def web_annotation(start, end, tag, text):
    return {
        '@context': 'http://www.w3.org/ns/anno.jsonld',
        'body': [{
            'purpose': 'tagging',
            'type': 'TextualBody',
            'value': tag
        }],
        'id': str(uuid.uuid4()),
        'target': {
            'selector': [
                {
                    'exact': text,
                    'type': 'TextQuoteSelector'
                },
                {
                    'end': end,
                    'start': start,
                    'type': 'TextPositionSelector'
                }
            ]
        },
        'type': 'Annotation'
    }

def get_answers(event, label, reviewer):
    doc = nlp(event['data']['abstract'])

    annos = []
    for ent in doc.ents:
        anno = web_annotation(
            ent.start_char,
            ent.end_char,
            ent.label_,
            str(ent)
        )
        annos.append(anno)

    answer = {
        'data': {
            'answer': annos,
            'document': event['hash'],
            'label': label['hash'],
            'reviewer': reviewer,
            'timestamp': math.floor(time.time())
        },
        'type': 'label-answer'
    }
    return answer

config = json.load(open(os.environ['SR_CONFIG']))
labels = config['current_labels']
annotation_label = labels[0]

nlp = spacy.load(config['current_step']['model'] + '/model-last')

with open(os.environ['SR_INPUT']) as sr_input, open(os.environ['SR_OUTPUT'], 'a') as sr_output:
    for line in sr_input:
        sr_output.write(line)
        sr_output.flush()
        event = json.loads(line)
        if event['type'] == 'document' and event['data'].get('abstract'):
            answer = get_answers(event, annotation_label, config['reviewer'])
            sr_output.write(json.dumps(answer))
            sr_output.flush()
