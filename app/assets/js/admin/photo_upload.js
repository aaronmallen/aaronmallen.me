const PHOTO = "photo";
const TOKEN = "_csrf_token";

export function formToken(form) {
  return new FormData(form ?? undefined).get(TOKEN) ?? "";
}

export async function uploadPhoto(endpoint, file, form, failed) {
  const data = new FormData();
  data.append(PHOTO, file);

  let response;
  try {
    response = await fetch(endpoint, {
      method: "POST",
      body: data,
      headers: { Accept: "application/json", "X-CSRF-Token": formToken(form) },
      redirect: "manual",
    });
  } catch {
    throw new Error(failed);
  }

  const answer = await response.json().catch(() => ({}));
  if (response.ok && answer.url) return answer;

  throw new Error(answer.error ?? failed);
}
