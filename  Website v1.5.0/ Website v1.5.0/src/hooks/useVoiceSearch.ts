"use client";

import { useCallback, useEffect, useRef, useState } from "react";

// Browser Speech Recognition (Chrome/Edge/Safari); unsupported browsers hide the mic.
const getRecognitionCtor = (): any =>
  typeof window === "undefined"
    ? null
    : (window as any).SpeechRecognition ||
      (window as any).webkitSpeechRecognition ||
      null;

const useVoiceSearch = (
  onResult: (text: string) => void,
  onError?: (code: string) => void,
) => {
  const [supported, setSupported] = useState(false);
  const [listening, setListening] = useState(false);
  const [interim, setInterim] = useState("");
  const recognitionRef = useRef<any>(null);
  const onResultRef = useRef(onResult);
  const onErrorRef = useRef(onError);

  useEffect(() => {
    onResultRef.current = onResult;
    onErrorRef.current = onError;
  }, [onResult, onError]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- feature detection needs window, so only after mount
    setSupported(!!getRecognitionCtor());
    return () => recognitionRef.current?.abort?.();
  }, []);

  const start = useCallback(() => {
    const Ctor = getRecognitionCtor();
    if (!Ctor || listening) return;
    // Mic access needs a secure origin (https or localhost); http on a LAN IP always fails.
    if (!window.isSecureContext) {
      onErrorRef.current?.("insecure-context");
      return;
    }
    const recognition = new Ctor();
    recognition.lang = document.documentElement.lang || navigator.language || "en-US";
    recognition.interimResults = true;
    recognition.maxAlternatives = 1;
    recognition.onresult = (event: any) => {
      let finalText = "";
      let interimText = "";
      for (let i = event.resultIndex; i < event.results.length; i++) {
        const chunk = event.results[i][0]?.transcript || "";
        if (event.results[i].isFinal) finalText += chunk;
        else interimText += chunk;
      }
      setInterim(interimText);
      if (finalText.trim()) onResultRef.current(finalText.trim());
    };
    recognition.onerror = (event: any) => {
      setListening(false);
      setInterim("");
      // "aborted" is our own stop(); not worth surfacing.
      if (event?.error && event.error !== "aborted") onErrorRef.current?.(event.error);
    };
    recognition.onend = () => {
      setListening(false);
      setInterim("");
    };
    recognitionRef.current = recognition;
    setListening(true);
    try {
      recognition.start();
    } catch {
      setListening(false);
      onErrorRef.current?.("start-failed");
    }
  }, [listening]);

  const stop = useCallback(() => {
    recognitionRef.current?.stop?.();
    setListening(false);
    setInterim("");
  }, []);

  return { supported, listening, interim, start, stop };
};

export default useVoiceSearch;
