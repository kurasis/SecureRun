import type { EngineHealth } from './contracts.ts';
import type { Language } from './strings.ts';

export function escaped(value: string): string {
  return value.replace(/[\p{Cc}\p{Cf}\u2028\u2029]/gu,
    character => `[U+${character.codePointAt(0)!.toString(16).toUpperCase().padStart(4, '0')}]`);
}
export type Setup = 'checking'|'missing'|'untrusted'|'unavailable'|'restart'|'untested'|'ready';
export function setupState(health: EngineHealth | null, fresh: boolean): Setup {
  if (!health || !fresh) return 'checking';
  const o = health.observation;
  if (o.reason === 'ENGINE_MISSING') return 'missing';
  if (o.restart_required) return 'restart';
  if (/VERSION_UNTESTED|MANIFEST_VERSION_UNSUPPORTED/.test(o.reason)) return 'untested';
  if (/UNTRUSTED|SIGNATURE|IMAGE_MISMATCH|COMPONENT_|ACL_|SERVICE_PATH/.test(o.reason)) return 'untrusted';
  if (o.trust !== 'VERIFIED' || !o.service_running || !o.driver_running || !o.service_identity_complete || !health.control_plane_safe) return 'unavailable';
  return 'ready';
}
export const productText = {
  en: {
    applications:'Applications', processes:'Processes', files:'Files', permissions:'Permissions', activity:'Activity', retention:'Retention and recovery',
    checking:'Checking engine', missing:'Engine not installed', untrusted:'Installation untrusted', unavailable:'Service or context unavailable', restart:'Restart required', untested:'Version not tested', ready:'Engine ready',
    install:'Install the original engine separately from the official project, then choose Recheck. Keep Windows security protections enabled.',
    official:'Official Sandboxie installation', recheck:'Recheck', create:'Create environment', choose:'Choose an environment', selected:'Selected environment',
    empty:'Create your first environment', emptyDetail:'Start with Standard offline. Review its host read-access limits before creating it.',
    none:'No matching environments', status:'Activity', eligibility:'New launches', count:'Processes', unknown:'Unknown', allowed:'Current prerequisites satisfied', blocked:'Blocked — review the reason',
    stale:'Observation is stale. Activity is unknown; it does not authorize cleanup.', back:'All environments', close:'Close', cancel:'Cancel',
    keyboard:'Keyboard: Ctrl+1 environments, Ctrl+, settings, F6 navigation; arrow keys switch environment tabs.', skip:'Skip to workspace',
    scope:'Manager events record requests and observed results, not target completion or engine access auditing.', history:'Manager operation history',
    sessionOnly:'Some events may be available only in this session. Persistent history could not be confirmed; recheck engine and installation trust.', emptyHistory:'No manager events recorded.',
    preview:'Review diagnostic bundle', previewTitle:'Exact redacted diagnostic bundle', review:'Review this exact JSON before choosing Save. It contains no paths, arguments, file contents or certificates. Nothing is uploaded. Existing files are never replaced.',
    save:'Save reviewed JSON…', saved:'Reviewed diagnostics saved. The file was not opened.', expiry:'The preview expires after 60 seconds and is consumed by Save or Cancel.',
    retentionHistory:'History retains at most 512 structured events for 30 days. Engine access events are unavailable.', free:'Available volume space', advisory:'Volume observations are advisory. They are not per-environment storage quotas or resource limits.', low:'Low available volume space. Save important data and free space before another write.',
    failure:'The action could not complete', cause:'Cause', next:'Next step', diagnostic:'Diagnostic ID and technical code',
    engineCause:'The engine or manager context cannot currently be verified.', engineNext:'Open Settings, follow the official installation guidance and Recheck.',
    busyCause:'This environment is running or another operation owns the namespace.', busyNext:'Wait for the operation, or Stop the entire environment and Recheck.',
    policyCause:'The current configuration differs from the verified policy or a required capability is unavailable.', policyNext:'Inspect Permissions and the current diff. Stop the environment before reviewed repair.',
    pathCause:'The selected file, filename or storage identity is unsafe or has changed.', pathNext:'Choose a regular file or a new ordinary output name with its full extension; Rename or Skip collisions.',
    unknownCause:'The operation outcome is uncertain. The target may already have executed.', unknownNext:'Recheck its journal and use safe Stop when available. A new explicit launch may repeat work; never replay the old request.',
    staleCause:'The selection, generation or observation has expired.', staleNext:'Recheck current state and make a fresh selection.',
    genericCause:'The backend refused the requested action or could not confirm its result.', genericNext:'Recheck current state and inspect its operation history before a new action.',
    mandatory:'Mandatory system protections — read only', mandatoryDetail:'Manager metadata, private roots and sibling environments remain protected. Editable personal-folder rules cannot remove these protections.',
    paid:'Privacy + hardened — unavailable', paidReason:'A supported, independently verified entitlement and enforcement are required. Standard remains available without a certificate.',
    clipboard:'Clipboard and device restrictions — unavailable', clipboardReason:'This adapter does not advertise verified clipboard or device controls.',
    diff:'Review effective permission changes', diffDetail:'Applying replaces editable rules with the list shown here. Any reduction of a previous exclusion can expose host reads. Desired changes to a running box remain unapplied until the whole box stops.',
    confirmDiff:'I reviewed this replacement and its host-read implications', mode:'Retention mode', persistent:'Persistent — keep data', disposable:'Disposable — explicit leftover decision',
    stopAll:'Stop managed environments…', stopTitle:'Stop exactly these managed environments', stopDetail:'Only the listed identities are requested. Each scope is independently rechecked; unrelated or newly created environments are not added.', stopAccept:'Stop listed environments',
    observed:'Observed', refused:'Refused', uncertain:'Outcome unknown', scale:'Content scale', technical:'Read-only engine details',
  },
  ru: {
    applications:'Приложения', processes:'Процессы', files:'Файлы', permissions:'Разрешения', activity:'История', retention:'Хранение и восстановление',
    checking:'Проверка движка', missing:'Движок не установлен', untrusted:'Установке нельзя доверять', unavailable:'Служба или контекст недоступны', restart:'Нужна перезагрузка', untested:'Версия не проверена', ready:'Движок готов',
    install:'Установите оригинальный движок отдельно с официального сайта и нажмите «Перепроверить». Сохраняйте защитные функции Windows включёнными.',
    official:'Официальная установка Sandboxie', recheck:'Перепроверить', create:'Создать окружение', choose:'Выберите окружение', selected:'Выбранное окружение',
    empty:'Создайте первое окружение', emptyDetail:'Начните со Standard offline. Перед созданием изучите ограничения защиты от чтения хоста.',
    none:'Совпадений нет', status:'Активность', eligibility:'Новые запуски', count:'Процессы', unknown:'Неизвестно', allowed:'Текущие условия выполнены', blocked:'Заблокированы — изучите причину',
    stale:'Наблюдение устарело. Активность неизвестна; это не разрешает очистку.', back:'Все окружения', close:'Закрыть', cancel:'Отмена',
    keyboard:'Клавиши: Ctrl+1 — окружения, Ctrl+, — настройки, F6 — навигация; стрелки переключают вкладки окружения.', skip:'Перейти к рабочей области',
    scope:'История менеджера отражает запросы и наблюдаемые результаты, а не завершение программы или аудит доступа движка.', history:'История операций менеджера',
    sessionOnly:'Часть событий может быть доступна только в текущем сеансе. Постоянная история не подтверждена; перепроверьте движок и подлинность установки.', emptyHistory:'Событий менеджера пока нет.',
    preview:'Просмотреть диагностический пакет', previewTitle:'Точный обезличенный диагностический пакет', review:'Просмотрите этот JSON перед сохранением. Он не содержит путей, аргументов, содержимого файлов и сертификатов. Ничего не отправляется в сеть. Существующие файлы не заменяются.',
    save:'Сохранить просмотренный JSON…', saved:'Просмотренная диагностика сохранена. Файл не открывался.', expiry:'Просмотр действует 60 секунд и расходуется при сохранении или отмене.',
    retentionHistory:'История хранит не более 512 структурированных событий за 30 дней. События доступа движка недоступны.', free:'Свободное место на томе', advisory:'Данные о томе справочные. Это не квоты хранилища или ограничения ресурсов окружения.', low:'На томе мало свободного места. Сохраните важные данные и освободите место перед новой записью.',
    failure:'Действие не завершено', cause:'Причина', next:'Следующий шаг', diagnostic:'Диагностический ID и технический код',
    engineCause:'Сейчас невозможно подтвердить движок или контекст менеджера.', engineNext:'Откройте настройки, изучите официальную инструкцию установки и перепроверьте состояние.',
    busyCause:'В окружении работают процессы либо пространство имён занято другой операцией.', busyNext:'Дождитесь операции либо остановите всё окружение и перепроверьте состояние.',
    policyCause:'Текущая конфигурация отличается от проверенной политики либо нужная возможность недоступна.', policyNext:'Изучите изменения в «Разрешениях». Перед проверенным исправлением остановите окружение.',
    pathCause:'Выбранный файл, имя или идентичность хранилища небезопасны либо изменились.', pathNext:'Выберите обычный файл или новое имя с полным расширением. При совпадении переименуйте или пропустите файл.',
    unknownCause:'Результат операции неизвестен. Программа могла уже выполнить работу.', unknownNext:'Перепроверьте журнал и при возможности безопасно остановите окружение. Новый явный запуск может повторить работу; не повторяйте старый запрос.',
    staleCause:'Выбор, поколение или наблюдение устарели.', staleNext:'Перепроверьте состояние и сделайте новый выбор.',
    genericCause:'Серверная часть отклонила действие или не смогла подтвердить результат.', genericNext:'Перепроверьте состояние и изучите историю перед новым действием.',
    mandatory:'Обязательные системные правила — только чтение', mandatoryDetail:'Метаданные менеджера, приватные корни и соседние окружения защищены. Личные правила не могут убрать эту защиту.',
    paid:'Privacy + hardened — недоступно', paidReason:'Нужны поддерживаемое проверенное право и подтверждённые ограничения. Standard доступен без сертификата.',
    clipboard:'Ограничения буфера обмена и устройств — недоступны', clipboardReason:'Этот адаптер не заявляет проверенные ограничения буфера обмена и устройств.',
    diff:'Проверьте изменения разрешений', diffDetail:'Применение заменит личные правила показанным списком. Ослабление прежнего запрета может раскрыть чтение хоста. Изменения работающего бокса не применяются до его полной остановки.',
    confirmDiff:'Я проверил замену правил и её влияние на чтение хоста', mode:'Режим хранения', persistent:'Persistent — сохранять данные', disposable:'Disposable — явное решение об остатках',
    stopAll:'Остановить управляемые окружения…', stopTitle:'Остановить именно эти окружения', stopDetail:'Запрашиваются только показанные идентичности. Каждый контекст перепроверяется; чужие и новые окружения не добавляются.', stopAccept:'Остановить показанные окружения',
    observed:'Наблюдалось', refused:'Отклонено', uncertain:'Результат неизвестен', scale:'Масштаб содержимого', technical:'Подробности движка для чтения',
  },
} as const;
export function errorText(code:string,language:Language) {
  const t=productText[language];
  if(code==='DESTINATION_EXISTS')return language==='ru'?{cause:'Файл с таким именем уже существует. Его данные сохранены.',next:'Повторно просмотрите пакет и сохраните его под новым именем с расширением .json.'}:{cause:'A file with this name already exists. Its data is unchanged.',next:'Review the bundle again and save it under a new name ending in .json.'};
  if(code==='CREATED_RETENTION_NOT_CONFIRMED')return language==='ru'?{cause:'Окружение создано, но изменение режима хранения не подтверждено.',next:'Закройте окно создания и проверьте фактический режим в разделе «Хранение и восстановление» перед запуском.'}:{cause:'The environment was created, but its retention change was not confirmed.',next:'Close creation and inspect the actual mode in Retention and recovery before launching.'};
  const group=/UNKNOWN|OUTCOME|NOT_CONFIRMED/.test(code)?'unknown':/EXPIRED|STALE|REVISION/.test(code)?'stale':/BUSY|STOP_REQUIRED|NAMESPACE/.test(code)?'busy':/PATH|LEAF|FILE_|ROOT|COLLISION|SELECTION/.test(code)?'path':/POLICY|HOOK|AUTOMATION|TEMPLATE|ENTITLE|CAPABILITY/.test(code)?'policy':/ENGINE|SERVICE|CONTEXT|BRIDGE|TRUST|PROBE/.test(code)?'engine':'generic';
  return {cause:t[`${group}Cause`],next:t[`${group}Next`]};
}

export function statusName(value:string,language:Language):string {
 const pairs:Record<string,[string,string]>={
  PREPARED:['Waiting for explicit confirmation','Ожидается явное подтверждение'],ACTIVE:['Active','Активно'],ARCHIVED:['Archived','Архив'],PERSISTENT:['Persistent','Постоянное'],DISPOSABLE:['Disposable','Одноразовое'],
  RUNNING:['Running','Работает'],IDLE:['Idle','Простой'],UNKNOWN:['Unknown','Неизвестно'],UNVERIFIED:['Needs verification','Нужна проверка'],VERIFIED:['Verified for this configuration','Проверено для этой конфигурации'],CONFLICT:['Configuration changed','Конфигурация изменена'],
  INTENT:['Intent recorded','Намерение сохранено'],FENCED:['Launches fenced','Новые запуски заблокированы'],WRITING:['Writing reviewed policy','Применяется проверенная политика'],READBACK:['Reading back effective state','Перечитывается фактическое состояние'],PENDING_ROOT:['Storage not yet bound','Хранилище ещё не привязано'],ROOT_BOUND:['Storage identity bound','Хранилище привязано'],VERIFYING:['Verifying restrictions','Проверяются ограничения'],
  RESET:['Reset contents','Сброс содержимого'],REMOVE:['Remove environment','Удаление окружения'],ARCHIVE:['Archive','Архивирование'],UNARCHIVE:['Unarchive','Возврат из архива'],RESUME:['Keep and resume','Сохранение и продолжение'],
  RESERVED:['Dispatch reserved','Отправка зарезервирована'],ACCEPTED:['Engine accepted dispatch','Движок принял отправку'],COMPLETED:['Manager operation completed','Операция менеджера завершена'],REFUSED:['Refused','Отклонено'],COMPLETE:['Complete','Завершено'],COMPLETE_RECOVERED:['Reconciled complete','Завершение сверено'],DISCARDED:['Verified staging discarded','Проверенный остаток удалён'],
  COPYING:['Copying','Копирование'],MARKED:['Provenance recorded','Происхождение отмечено'],READY:['Ready for explicit action','Готово к явному действию'],PUBLISHED:['Published without replacement','Опубликовано без замены'],INCOMPLETE:['Incomplete','Не завершено'],CANCELLED:['Cancelled','Отменено'],
  SNAPSHOT_CAPTURED:['Restoration authority captured','Полномочия восстановления сохранены'],SEALED:['Namespace sealed','Пространство имён закрыто'],DISPATCH_RESERVED:['Cleanup dispatch reserved','Очистка зарезервирована'],NATIVE_RETURNED:['Native call returned','Нативная операция вернулась'],CLEARED:['Verified empty contents','Пустое содержимое проверено'],DEFINITION_REMOVED:['Definition absent','Определение удалено'],METADATA_COMMITTED:['Metadata reconciled','Метаданные сверены'],AWAITING_CONTROLLER_RESTORE:['Restoring surviving ACLs','Восстанавливаются права оставшихся объектов'],
 };
 const normalized=value.replace(/([a-z0-9])([A-Z])/g,'$1_$2').toUpperCase();const entry=pairs[normalized];return entry?entry[language==='ru'?1:0]:(language==='ru'?'Требуется проверка — код в подробностях':'Inspection required — see technical code');
}
