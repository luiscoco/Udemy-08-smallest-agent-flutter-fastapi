"""Run against this edition's running FastAPI server; never sends a paid request."""
import httpx

BASE = 'http://127.0.0.1:8300'
with httpx.Client(base_url=BASE, timeout=20) as client:
    assert client.get('/api/health').json() == {'status':'ok','api_key_configured':False}
    assert client.get('/docs').status_code == 200
    assert '/api/agent/stream' in client.get('/openapi.json').json()['paths']
    assert client.get('/api/unknown').status_code == 404
    for mode in ['query','stream']:
        path = f'/api/agent/{mode}'
        for origin in [BASE,'http://127.0.0.1:4900','http://localhost:4900']:
            response = client.post(path,json={'prompt':''},headers={'Origin':origin})
            assert response.status_code == 422
            if ':4900' in origin:
                assert response.headers['access-control-allow-origin'] == origin
        assert client.post(path,json={'prompt':'Hi'},headers={'Origin':'https://foreign.invalid','X-Forwarded-Host':'foreign.invalid'}).status_code == 403
        assert client.post(path,content='{}',headers={'Content-Type':'text/plain'}).status_code == 415
        assert client.post(path,content='{broken',headers={'Content-Type':'application/json'}).status_code == 400
        assert client.post(path,json={'prompt':'x'*40000}).status_code == 413
    assert client.post('/api/agent/query',json={'prompt':'Hi'}).status_code == 503
    stream = client.post('/api/agent/stream',json={'prompt':'Hi'})
    assert stream.headers['content-type'].startswith('text/event-stream')
    assert 'event: error' in stream.text and 'event: done' not in stream.text
    if client.get('/').status_code == 200:
        for path in ['/flutter_bootstrap.js','/main.dart.js','/assets/assets/workflow.json','/assets/assets/workflow.svg','/assets/assets/workflow.puml','/assets/assets/astronaut.png']:
            assert client.get(path).status_code == 200, path
print('Real HTTP checks passed: docs/schema, health, validation, explicit Flutter origins, no-key query/SSE and available production assets.')
