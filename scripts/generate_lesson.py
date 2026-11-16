"""Extract actual Dart/Python excerpts and synchronize all 16 UML source cards."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILES = {
    'app': 'frontend/lib/app.dart', 'api': 'frontend/lib/api.dart',
    'code': 'frontend/lib/code_block.dart', 'main': 'backend/app/main.py',
    'service': 'backend/app/agent_service.py', 'schema': 'backend/app/schemas.py',
}


def excerpt(key, marker, count):
    lines = (ROOT / FILES[key]).read_text(encoding='utf-8').splitlines()
    start = next((i for i,line in enumerate(lines) if marker in line), None)
    if start is None:
        raise ValueError(f'Missing source marker: {FILES[key]} {marker}')
    selected = lines[start:start + count]
    indent = min((len(line)-len(line.lstrip()) for line in selected if line.strip()), default=0)
    return '\n'.join(line[indent:] for line in selected).rstrip()


def main():
    svg = (ROOT/'scripts/workflow-template.svg').read_text(encoding='utf-8')
    labels = [(int(number),title.replace('&amp;','&').replace('&gt;','>')) for number,title in re.findall(r'<text[^>]*>(\d+)\. ([^<]+)</text>',svg)]
    if [number for number,_ in labels] != list(range(1,17)):
        raise ValueError('Diagram must contain exactly 16 sequential unique labels')
    steps = []

    def step(number,key,marker,count,text,explanation):
        steps.append(dict(number=number,title=labels[number-1][1],source=FILES[key],language='dart' if FILES[key].endswith('.dart') else 'python',code=excerpt(key,marker,count),text=text,explanation=explanation))

    step(1,'app','final trimmed = prompt.text.trim()',5,'The Flutter action trims input and applies a synchronous duplicate-submit lock.','The server validates independently. The lock applies before awaiting any network operation.')
    step(2,'api',"final request = http.Request('POST'",4,'The Dart client posts a JSON prompt to the stream endpoint.','Production uses same-origin URLs. Development explicitly points to FastAPI on port 8300, which allows only the two local frontend origins.')
    step(3,'schema','class PromptRequest',3,'A strict Pydantic model trims the string and checks its bounds.','The ASGI boundary first checks actual bytes, Origin and content type. SDK options separately disable built-in tools.')
    step(4,'main','async with aclosing(agent.stream_agent',4,'FastAPI delegates execution to the Python agent service.','The server owns configuration and credentials. The generator scope closes the SDK iterator on completion or cancellation.')
    step(5,'service','source = self.query_fn',5,'The actual SDK query boundary owns the CLI runtime and model transport.','Application code supplies a prompt/options and observes SDK messages. The model HTTP exchange itself is internal to the SDK.')
    step(6,'service','async for message in source:',3,'Async iteration observes SDK messages until a final result appears.','The same small loop as the terminal lesson remains recognizable. Streaming projects intermediate messages while query mode returns a final answer.')
    step(7,'service',"yield {'type': kind",3,'Only allowlisted SDK projections leave the service.','Projection branches above this yield include text, system subtype and final metrics. Thinking, environment, tools and session IDs are excluded.')
    step(8,'main',"yield ServerSentEvent(event='message'",2,'FastAPI serializes a safe SDK projection into a native SSE frame.','EventSourceResponse handles heartbeat comments and disconnect cancellation. The route applies a three-minute execution deadline.')
    step(9,'app','if (messages.length < 500)',12,'Each received SDK message updates Flutter state.','The visible timeline is bounded. Final-result processing continues after 500 displayed rows. State belongs to this application instance.')
    step(10,'service','def result_data',9,'Normalize answer, turns, duration, estimated cost and SDK error status.','Exact key occurrences are redacted. Non-success subtypes stay failures; an unreported cost remains null.')
    step(11,'api','final message = AgentMessage.fromJson',4,'The Dart client runtime-validates every message and final result.','ResultMessage is a safe public projection. The application receives it in the same SSE message event as progress.')
    step(12,'code','Widget build(BuildContext context) => MarkdownBody(',7,'Render Markdown and fenced code as Flutter widgets.','No model HTML is inserted into the DOM or executed. Remote answer images are omitted and links are limited to HTTP(S). The pre builder colors fenced code.')
    step(13,'api',"if (frame.event == 'done')",9,'Require both a final result and the terminal done event.','The parser preserves split UTF-8, CRLF and multiline data. Completing the transport does not override a failed SDK result.')
    step(14,'main',"yield ServerSentEvent(event='error', data={'detail': FAILURE})",1,'A provider failure after SSE starts emits a safe error without done.','Query mode instead returns safe HTTP 502. Raw provider exceptions and submitted values are excluded.')
    step(15,'app','final message = err is ApiException',10,'Flutter shows the safe API error and a snackbar, then restores controls.','Specific validation/key errors survive the client boundary. Other network failures use a readable fallback; timers stop in finally.')
    step(16,'main',"yield ServerSentEvent(event='error', data={'detail': MISSING_KEY})",2,'A missing key stops execution before the SDK is called.','Query returns HTTP 503; stream sends error without done. Invalid inputs are rejected before route execution. Neither path spends model credits.')
    if len(steps)!=16 or [step['number'] for step in steps]!=list(range(1,17)):
        raise ValueError('Source/diagram step mismatch')
    assets = ROOT/'frontend/assets'
    assets.mkdir(parents=True,exist_ok=True)
    (assets/'workflow.json').write_text(json.dumps(steps,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    (assets/'workflow.svg').write_text(svg,encoding='utf-8')
    (assets/'workflow.puml').write_bytes((ROOT/'scripts/workflow-template.puml').read_bytes())
    print('Generated 16 Flutter/Dart and FastAPI/Python source cards with matching UML downloads.')


if __name__ == '__main__':
    main()
