const PHOTO = "photo";

export async function uploadPhoto(endpoint, file, token, failed) {
  const data = new FormData();
  data.append(PHOTO, file);

  let response;
  try {
    response = await fetch(endpoint, {
      method: "POST",
      body: data,
      headers: { Accept: "application/json", "X-CSRF-Token": token },
      redirect: "manual",
    });
  } catch {
    throw new Error(failed);
  }

  const answer = await response.json().catch(() => ({}));
  if (response.ok && answer.url) return answer;

  throw new Error(answer.error ?? failed);
}
