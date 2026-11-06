import { loadFirebaseAuth } from "@/utils/lazyFirebaseAuth";

// Shared module-level RecaptchaVerifier instance across auth flows.
let verifier: any = null;
let verifierContainerId: string | null = null;

export const clearRecaptchaVerifier = (): void => {
  const container = verifierContainerId
    ? document.getElementById(verifierContainerId)
    : null;
  if (verifier && container && document.body.contains(container)) {
    try {
      verifier.clear();
    } catch (error: any) {
      console.log("recaptcha clear failed", error);
    }
  }
  if (container && document.body.contains(container)) {
    container.innerHTML = "";
  }
  verifier = null;
  verifierContainerId = null;
};

// Rebuild and initialize a fresh RecaptchaVerifier instance.
export const getRecaptchaVerifier = async (containerId: string): Promise<any> => {
  clearRecaptchaVerifier();
  const oldContainer = document.getElementById(containerId);
  if (!oldContainer) return null;
  const container = oldContainer.cloneNode(false) as HTMLElement;
  oldContainer.replaceWith(container);

  const { auth, RecaptchaVerifier } = await loadFirebaseAuth();
  verifier = new RecaptchaVerifier(auth, container, {
    size: "invisible",
    "expired-callback": () => {
      console.log("[recaptcha] widget expired");
      verifier = null;
      verifierContainerId = null;
    },
  });
  verifierContainerId = containerId;
  return verifier;
};

