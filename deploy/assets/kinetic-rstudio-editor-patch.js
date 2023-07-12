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
    const quitBtn = document.querySelector('#rstudio_tb_quitsession')
    document.querySelector('#rstudio_project_menubutton_toolbar').remove()
    this.buttonsContainer = document.createElement('div')
    quitBtn.parentElement.appendChild(this.buttonsContainer)
    Object.assign(this.buttonsContainer.style, {
      position: 'absolute',
      top: '8px',
      right: '8px',
      height: '50px',
      display: 'flex',
      zIndex: 2,
    })

    //this.buttonsContainer = quitBtn.parentElement
    quitBtn.closest('table').querySelectorAll('button,.gwt-Label').forEach((el) => {
      el.remove()
    })

  }


  handle_addButton({ id, title, svg, style = {} }) {
    const btn = document.createElement('button')
    Object.assign(btn.style, {
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      height: '100%',
      justifyContent: 'center',
      backgroundColor: '#F8D5CD',
      gap: '4px',
      color: '#000',
      ...style,
    })
    btn.title = title
    btn.addEventListener('click', () => this.sendCommand('buttonClick', { id }))
    btn.innerHTML = `${svg}<span>${title}</span>`
    this.buttonsContainer.appendChild(btn)
  }
}

function onReady() {
  new RStudioButtons()
}

function waitForBoot(delay = 1000) {
  if (document.querySelector('#rstudio_container')) {
    setTimeout(onReady, 200);
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
