#!/usr/bin/env python
import json, math, os, spacy, time, uuid, time, asyncio, re, zipfile, requests, sys

def download(url, filename, msg):
    sys.stdout.write(msg)
    with open(filename, 'wb') as f:
        response = requests.get(url, stream=True)
        total = response.headers.get('content-length')

        if total is None:
            f.write(response.content)
        else:
            downloaded = 0
            total = int(total)
            for data in response.iter_content(chunk_size=max(int(total/1000), 1024*1024)):
                downloaded += len(data)
                f.write(data)
                done = int(50*downloaded/total)
                sys.stdout.write('\r[{}{}]'.format('=' * done, '.' * (50-done)))
                sys.stdout.flush()
    sys.stdout.write('\n')

def unzip(file,path): 
    with zipfile.ZipFile(file,'r') as zip_ref:
        zip_ref.extractall(path)
        zip_ref.close()

def get_spacy_model(url):
    "download a spacy model from a url and unzip into data/spacy"
    if not os.path.exists("data/spacy.zip"): download(url, "data/spacy.zip", "downloading spacy model\n")
    if not os.path.exists("data/spacy"): unzip("data/spacy.zip","data")        
    return spacy.load("data/spacy")

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