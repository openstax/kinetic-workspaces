function onReady(returnBtn) {
    const parentHostname = window.location.origin.replace(/\/\/\w+\./, '//')
    window.parent.postMessage({
      source: 'rstudio',
      command: 'inactive',
      payload: {},
    }, parentHostname);
    returnBtn.addEventListener('click', (ev) => {
      ev.preventDefault()
      window.parent.postMessage({
        source: 'rstudio',
        command: 'active',
        payload: {},
      }, parentHostname);
    });
}

function waitForBoot(delay = 1000) {
  const returnBtn = document.querySelector('.signinhidden button')
  if (returnBtn) {
    onReady(returnBtn)
  } else {
    setTimeout(waitForBoot, () => ready(delay * 1.2));
  }
}

function onDocReady(fn) {
  if (document.readyState !== 'loading') {
    fn();
    return;
  }
  document.addEventListener('DOMContentLoaded', fn);
}

onDocReady(waitForBoot);
