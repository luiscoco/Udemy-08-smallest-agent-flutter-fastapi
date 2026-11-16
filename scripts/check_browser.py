"""Optional browser QA: pip install playwright; uses installed Chrome, not model credits."""
import argparse
import json
import httpx
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

parser=argparse.ArgumentParser()
parser.add_argument('--url',default='http://127.0.0.1:8300')
args=parser.parse_args()
if httpx.get('http://127.0.0.1:8300/api/health',timeout=10).json().get('api_key_configured'):
    raise RuntimeError('This no-credit browser check requires an unconfigured test backend; no prompt was submitted.')
root=Path(__file__).resolve().parents[1]
out=root/'verification'
out.mkdir(exist_ok=True)
chrome=Path('C:/Program Files/Google/Chrome/Application/chrome.exe')
with sync_playwright() as p:
    browser=p.chromium.launch(executable_path=str(chrome),headless=True)
    page=browser.new_page(viewport={'width':1440,'height':1100},device_scale_factor=1)
    errors=[]
    page.on('pageerror',lambda error: errors.append(str(error)))
    page.goto(args.url)
    page.wait_for_selector('flutter-view',timeout=120000)
    page.locator('flt-semantics-placeholder').evaluate('(element) => element.click()')
    prompt=page.get_by_role('textbox',name='What would you like to ask?')
    expect(prompt).to_be_visible(timeout=60000)
    prompt.click()
    prompt.press('Control+A')
    prompt.press('Backspace')
    prompt.press_sequentially('Remember this browser question')
    page.screenshot(path=str(out/'desktop.png'))
    for label,heading in [('What you will learn','Small enough to understand. Real enough to explore.'),('How to run','Two terminals. One learning application.'),('Architecture & workflow','See how the pieces connect.'),('Code walkthrough','The same loop. A Flutter application.'),('Application lab','Start with a little curiosity.')]:
        page.get_by_role('button',name=label,exact=True).click()
        expect(page.get_by_text(heading,exact=True)).to_be_visible()
        if label=='Architecture & workflow':
            page.get_by_text('From a click to a final answer',exact=True).scroll_into_view_if_needed()
            page.screenshot(path=str(out/'architecture.png'))
            with page.expect_download() as pending_download:
                page.get_by_role('button',name='Download UML (SVG)',exact=True).click()
            assert pending_download.value.suggested_filename == 'workflow.svg'
            page.mouse.move(1435,100)
            page.mouse.wheel(0,900)
            page.wait_for_timeout(300)
            page.screenshot(path=str(out/'workflow.png'))
            page.mouse.wheel(0,1600)
            page.wait_for_timeout(300)
            page.screenshot(path=str(out/'source-code.png'))
    # Flutter's unfocused semantics textarea does not mirror controller.value.
    # Verify retention through the actual POST body after revisiting every tab.
    with page.expect_request(lambda request: request.method == 'POST' and request.url.endswith('/api/agent/stream')) as pending_request:
        page.get_by_role('button',name='Run agent ↗',exact=True).click()
    assert json.loads(pending_request.value.post_data)['prompt'] == 'Remember this browser question'
    expect(page.get_by_text('Configure ANTHROPIC_API_KEY in this application\'s backend/.env file, then restart FastAPI.',exact=True).first).to_be_visible(timeout=15000)
    page.get_by_role('button',name='Switch to dark mode',exact=True).click()
    page.reload()
    page.wait_for_selector('flutter-view')
    page.locator('flt-semantics-placeholder').evaluate('(element) => element.click()')
    expect(page.get_by_role('button',name='Switch to light mode',exact=True)).to_be_visible(timeout=30000)
    page.get_by_role('button',name='Switch to light mode',exact=True).click()
    page.set_viewport_size({'width':430,'height':930})
    page.screenshot(path=str(out/'mobile.png'))
    assert not errors, errors
    browser.close()
print('Chrome browser checks passed: tab clicks, retained prompt, missing-key Stream error, persistent theme and mobile/desktop screenshots.')
