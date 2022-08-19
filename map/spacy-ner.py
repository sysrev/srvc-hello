#!/usr/bin/env python
import json, math, os, spacy, time, uuid, time, asyncio, re, requests, pickle

def get_spacy_model(url="https://s3.amazonaws.com/ins.pins/spacy-entox.pickle"):
    file="data/spacy-entox.pickle"
    if not os.path.exists(file):
        with open(file, 'wb') as fout:
            response = requests.get(url, stream=True)
            for block in response.iter_content(4096): 
                fout.write(block)
    return pickle.load(open("data/spacy-entox.pickle","rb"))

def web_annotation(start, end, tag, text):
    return { '@context': 'http://www.w3.org/ns/anno.jsonld',
        'id': str(uuid.uuid4()),
        'body': [{'purpose': 'tagging', 'type': 'TextualBody', 'value': tag}],
        'target': {
            'selector': [
                {'exact': text, 'type': 'TextQuoteSelector'},
                {'end': end, 'start': start, 'type': 'TextPositionSelector' }
            ]
        }, 'type': 'Annotation' }

def get_answer(nlp, event, label, reviewer):
    doc = nlp(re.sub('\n','',event['data']['abstract'])) # spacy ignores newlines
    ann = [web_annotation(e.start_char, e.end_char, e.label_, str(e)) for e in doc.ents]

    data = { 'answer':ann, 'document':event['hash'], 'label':label['hash'], 'reviewer':reviewer }
    data['timestamp'] = math.floor(time.time())
    return {'data': data, 'type':'label-answer'}

async def main():
    ihost,iport = os.environ["SR_INPUT"].split(":")
    sr_input, _ = await asyncio.open_connection(ihost, iport)
    
    ohost,oport = os.environ["SR_OUTPUT"].split(":")
    _, sr_output = await asyncio.open_connection(ohost, oport)

    config = json.load(open(os.environ['SR_CONFIG']))
    annotation_label = config['current_labels'][0] # TODO how to get the annotation label?
    nlp = get_spacy_model(config['current_step']['model'])

    while True:
        line = await sr_input.readline()
        if not line: break;

        sr_output.write(line)
        await sr_output.drain()

        event = json.loads(line.decode().rstrip())
        if event['type'] == 'document' and event['data'].get('abstract'):
            answer = json.dumps(get_answer(nlp, event, annotation_label, config['reviewer']))
            sr_output.write(f"{answer}\n".encode()) # TODO python library should provide all this logic
            await sr_output.drain()

asyncio.run(main())