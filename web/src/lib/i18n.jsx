import { createContext, useContext } from 'react';

export const LocaleCtx = createContext({ t: (k, d) => d, lang: 'id' });
export const useT = () => useContext(LocaleCtx).t;
export const useLang = () => useContext(LocaleCtx).lang;
