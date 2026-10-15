import {escaped,errorText,productText} from './product';
import type {Language} from './strings';
export function ErrorView({code,language,action,diagnosticId}:{code:string;language:Language;action?:string;diagnosticId?:string}) {
  const t=productText[language];const explanation=errorText(code,language);
  return <section className="error" role="alert"><h3>{t.failure}{action?` · ${escaped(action)}`:''}</h3><p><strong>{t.cause}:</strong> {explanation.cause}</p><p><strong>{t.next}:</strong> {explanation.next}</p><details><summary>{t.diagnostic}</summary><code>{escaped(code)}</code>{diagnosticId&&<p><code>{escaped(diagnosticId)}</code></p>}</details></section>;
}
