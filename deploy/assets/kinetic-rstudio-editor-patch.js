class RStudioButtons {

  constructor() {
    this.removeButtons()
    // strip off our randomly generated subdomain to get parent's address
    this.parentHostname = window.location.origin.replace(/\/\/\w+\./, '//')
    window.addEventListener('message', this.onMessage, false);
    this.sendCommand('ready')
  }


  onMessage = ({ data }) => {
    try {
      if (data?.target !== 'rstudio') return
      this[`handle_${data.command}`](data.payload)

      } catch (e) {
        console.warn(e)
      }
  }

  sendCommand(command, payload = {}) {
    window.parent.postMessage({
      source: 'rstudio',
      command,
      payload,
    }, this.parentHostname);
  }

  removeButtons() {
    [
      '#rstudio_container > div:nth-child(2) > div > div:nth-child(2) > div > div > table > tbody > tr > td > table > tbody > tr > td:nth-child(2) > table > tbody > tr > td:nth-child(4)',
      '#rstudio_container > div:nth-child(2) > div > div:nth-child(2) > div > div > table > tbody > tr > td > table > tbody > tr > td:nth-child(2) > table > tbody > tr > td:nth-child(2)',
    ].forEach(s => {
      document.querySelector(s).remove()
    })

    const quitBtn = document.querySelector('#rstudio_tb_quitsession')
    this.buttonsContainer = quitBtn.parentElement
    quitBtn.remove()
  }


  handle_addButton({ id, title, svg, style = {} }) {
    const btn = document.createElement('button')
    Object.assign(btn.style, { display: 'flex', ...style })
    btn.title = title
    btn.addEventListener('click', () => this.sendCommand('buttonClick', { id }))
    btn.innerHTML = svg
    this.buttonsContainer.appendChild(btn)
  }
}

function onReady() {
  new RStudioButtons()
}

function waitForBoot(delay = 5000) {
  if (document.querySelector('#rstudio_container')) {
    setTimeout(onReady, 1000);
  } else {
    setTimeout(waitForBoot, () => ready(delay * 2));
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
