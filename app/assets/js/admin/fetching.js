const DELAY = 300;

export function setupFetch({ delay = DELAY, queue = false, request, read = text, done, failed = () => {} }) {
  let again = null;
  let controller = null;
  let timer = null;

  const stop = () => {
    again = null;
    clearTimeout(timer);
    controller?.abort();
    controller = null;
  };

  const settle = () => {
    const args = again;
    controller = null;
    if (args) later(...args);
  };

  const now = async (...args) => {
    stop();
    controller = new AbortController();
    const { signal } = controller;

    let answer;
    try {
      const { url, ...init } = request(...args);
      answer = await read(await fetch(url, { ...init, signal }));
    } catch (error) {
      if (signal.aborted) return;
      settle();
      failed(error, ...args);
      return;
    }

    if (signal.aborted) return;
    settle();
    done(answer, ...args);
  };

  const later = (...args) => {
    if (queue && controller) {
      again = args;
      return;
    }

    stop();
    timer = setTimeout(() => now(...args), delay);
  };

  return { later, now, stop };
}

export function json(response) {
  return checked(response).json();
}

export function text(response) {
  return checked(response).text();
}

function checked(response) {
  if (!response.ok) throw new Error(`${response.url} answered ${response.status}`, { cause: response });

  return response;
}
