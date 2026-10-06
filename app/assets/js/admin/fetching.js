const DELAY = 300;

export function setupFetch({ delay = DELAY, request, read = text, done, failed = () => {} }) {
  let controller = null;
  let timer = null;

  const stop = () => {
    clearTimeout(timer);
    controller?.abort();
    controller = null;
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
      if (!signal.aborted) failed(error, ...args);
      return;
    }

    if (!signal.aborted) done(answer, ...args);
  };

  const later = (...args) => {
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
  if (!response.ok) throw new Error(`${response.url} answered ${response.status}`);

  return response;
}
