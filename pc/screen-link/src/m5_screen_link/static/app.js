const targetIds = { cardputer: 1, stackchan: 2 }
const targetSizes = {
  cardputer: [240, 135],
  stackchan: [320, 240],
}

const elements = {
  token: document.querySelector('#token'),
  cardputer: document.querySelector('#cardputer'),
  stackchan: document.querySelector('#stackchan'),
  fps: document.querySelector('#fps'),
  quality: document.querySelector('#quality'),
  start: document.querySelector('#start'),
  stop: document.querySelector('#stop'),
  status: document.querySelector('#status'),
  source: document.querySelector('#source'),
  canvases: {
    cardputer: document.querySelector('#cardputer-canvas'),
    stackchan: document.querySelector('#stackchan-canvas'),
  },
}

let stream
let socket
let running = false
let sentFrames = 0
let startedAt = 0

function setStatus(message) {
  elements.status.textContent = message
}

function clamp(value, minimum, maximum) {
  return Math.min(maximum, Math.max(minimum, value))
}

function drawContained(video, canvas) {
  const context = canvas.getContext('2d', { alpha: false })
  const ratio = Math.min(canvas.width / video.videoWidth, canvas.height / video.videoHeight)
  const width = Math.round(video.videoWidth * ratio)
  const height = Math.round(video.videoHeight * ratio)
  const left = Math.floor((canvas.width - width) / 2)
  const top = Math.floor((canvas.height - height) / 2)
  context.fillStyle = '#000'
  context.fillRect(0, 0, canvas.width, canvas.height)
  context.drawImage(video, left, top, width, height)
}

function jpegBlob(canvas, quality) {
  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => (blob ? resolve(blob) : reject(new Error('JPEG encode failed'))), 'image/jpeg', quality)
  })
}

async function sendTarget(name, quality) {
  if (!elements[name].checked || socket.readyState !== WebSocket.OPEN) return
  const canvas = elements.canvases[name]
  drawContained(elements.source, canvas)
  const jpeg = new Uint8Array(await (await jpegBlob(canvas, quality)).arrayBuffer())
  const packet = new Uint8Array(jpeg.byteLength + 1)
  packet[0] = targetIds[name]
  packet.set(jpeg, 1)
  socket.send(packet)
  sentFrames += 1
}

async function frameLoop() {
  while (running) {
    const frameStarted = performance.now()
    const fps = clamp(Number(elements.fps.value) || 8, 1, 15)
    const quality = clamp(Number(elements.quality.value) || 60, 30, 90) / 100
    try {
      await sendTarget('cardputer', quality)
      await sendTarget('stackchan', quality)
    } catch (error) {
      setStatus(`送信エラー: ${error.message}`)
      stop()
      return
    }
    const elapsedSeconds = Math.max(0.001, (performance.now() - startedAt) / 1000)
    setStatus(`送信中: ${(sentFrames / elapsedSeconds).toFixed(1)} frames/s（2画面合計）`)
    const remaining = Math.max(0, 1000 / fps - (performance.now() - frameStarted))
    await new Promise((resolve) => setTimeout(resolve, remaining))
  }
}

async function start() {
  const token = elements.token.value.trim()
  if (!token) {
    setStatus('接続トークンを入力してください。')
    return
  }
  if (!elements.cardputer.checked && !elements.stackchan.checked) {
    setStatus('送信先を1台以上選んでください。')
    return
  }

  try {
    stream = await navigator.mediaDevices.getDisplayMedia({
      video: { frameRate: clamp(Number(elements.fps.value) || 8, 1, 15) },
      audio: false,
    })
    elements.source.srcObject = stream
    await elements.source.play()

    const scheme = location.protocol === 'https:' ? 'wss' : 'ws'
    socket = new WebSocket(`${scheme}://${location.host}/ws/producer`)
    await new Promise((resolve, reject) => {
      socket.addEventListener('open', resolve, { once: true })
      socket.addEventListener('error', () => reject(new Error('WebSocket接続に失敗しました')), { once: true })
    })
    await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('認証応答がありません')), 5000)
      const cleanup = () => {
        clearTimeout(timeout)
        socket.removeEventListener('message', onMessage)
        socket.removeEventListener('close', onClose)
      }
      const onMessage = (event) => {
        cleanup()
        try {
          const response = JSON.parse(event.data)
          if (response.status !== 'ready') throw new Error('認証が拒否されました')
          resolve()
        } catch (error) {
          reject(error)
        }
      }
      const onClose = () => {
        cleanup()
        reject(new Error('認証が拒否されました'))
      }
      socket.addEventListener('message', onMessage)
      socket.addEventListener('close', onClose)
      socket.send(token)
    })

    running = true
    sentFrames = 0
    startedAt = performance.now()
    elements.start.disabled = true
    elements.stop.disabled = false
    stream.getVideoTracks()[0].addEventListener('ended', stop, { once: true })
    void frameLoop()
  } catch (error) {
    setStatus(`開始できません: ${error.message}`)
    stop()
  }
}

function stop() {
  running = false
  if (socket) socket.close()
  if (stream) stream.getTracks().forEach((track) => track.stop())
  socket = undefined
  stream = undefined
  elements.source.srcObject = null
  elements.start.disabled = false
  elements.stop.disabled = true
  setStatus('停止中')
}

elements.start.addEventListener('click', start)
elements.stop.addEventListener('click', stop)
