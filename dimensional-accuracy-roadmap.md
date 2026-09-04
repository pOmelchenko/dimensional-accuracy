# Исследование решений для `dimensional-accuracy`

> Это не roadmap и не обещание конкретных релизов. Это проверяемая исследовательская записка:
> что уже делают похожие проекты, какие выводы действительно следуют из источников и
> каким, на мой взгляд, должен быть плагин.
>
> Последняя перепроверка источников: **4 сентября 2026 года**.
>
> Репозиторий: <https://github.com/pOmelchenko/dimensional-accuracy>

## 1. Как читать этот документ

В ранней версии здесь были смешаны четыре разных типа утверждений. Ниже они разделены:

- **факт** — подтверждён исходным проектом, документацией или исходным кодом;
- **интерпретация** — вывод из подтверждённых фактов;
- **гипотеза** — то, что необходимо проверить физическим экспериментом;
- **решение** — предлагаемое направление для `dimensional-accuracy`, а не свойство конкурента.

Чужая геометрия, текст и алгоритмы не считаются автоматически пригодными для копирования.
Лицензия и техническая полезность — разные вопросы. Если лицензия не найдена, безопасно
заимствовать только общую идею после самостоятельной реализации.

## 2. Краткий вывод

`dimensional-accuracy` имеет смысл не как ещё один calibration STL и не как универсальная
метрологическая платформа. Его сильная позиция — **PrusaSlicer-native помощник, который
связывает версионированный эталон, сырые измерения, понятную модель ошибки, безопасный
preview изменений профиля и обязательную проверочную печать**.

Главное, чего сейчас не хватает проекту, — не новых формул, а физических данных. Текущая
модель

```text
measured = scale × nominal + fixed_offset
```

математически разумна, но три размера `40 / 80 / 120 мм` дают модели с intercept всего одну
остаточную степень свободы. Этого мало, чтобы уверенно отличить масштабную ошибку материала
от ошибки измерения, шва, экструзии и геометрии эталона.

Поэтому ближайший полезный вопрос звучит так:

> Какая измерительная геометрия даёт повторяемые результаты после полного снятия и повторной
> установки штангенциркуля, у разных операторов, инструментов и независимых печатей?

До ответа на него усложнение solver-а создаст скорее ложную точность, чем точную калибровку.

## 3. Что уже есть в проекте

По состоянию исследованной ветки и PR [#1](https://github.com/pOmelchenko/dimensional-accuracy/pull/1):

- XY-эталон с внешними размерами `40 / 80 / 120 мм` вдоль X и Y;
- отдельный ступенчатый Z-эталон с высотами `40 / 80 / 120 мм`;
- объединённая XY+Z раскладка;
- Lua-генератор и Lua-калькулятор;
- OLS-fit модели scale-plus-offset;
- рекомендации для XY/Z shrinkage и `xy_size_compensation`;
- проверка residual, RMS, intercept и X/Y anisotropy;
- preview применения по умолчанию, подтверждения и валидация ввода;
- тесты, CI, staging bundle и собственный STL verifier;
- прототип более толстого XY-сечения и оконный Z-прототип.

Это уже хороший программный каркас. Однако в репозитории пока нет набора физических
экспериментов, который подтверждал бы:

1. удобство и однозначность установки губок;
2. повторяемость измерения;
3. устойчивость оценок scale и offset между печатями;
4. улучшение на независимой проверочной детали после применения компенсации.

Статус **experimental** поэтому корректен.

## 4. Перепроверка конкурирующих и соседних решений

### 4.1. Сводная таблица

| Решение | Что подтверждено | Что полезно здесь | Ограничение |
|---|---|---|---|
| K3D Accuracy | разделение scale и equidistant/contour error, weighted objectives, verification print | разделять масштабный и аддитивный эффекты; показывать before/after | опубликованную формулу offset нельзя переносить без проверки |
| Califlower / Calilantern | size + skew, web calculator, графики, итерационная проверка, три плоскости у Calilantern | эталон качества UX и объяснения результата | коммерческая лицензия запрещает reverse engineering/copying |
| Fleur de Cali / Calistar | outer/inner/diagonal measurements, 2–5 уровней, до трёх повторов, worksheet | повторы, сырой ввод, uncertainty hints, partial input, skew | GPL-3.0; геометрию/код можно использовать только с соблюдением лицензии |
| BoronTrident | machine и material calibration разделены; long-short differential; пять перестановок губок и медиана | регистрация губок, дифференциальные размеры, строгий протокол | явная лицензия репозитория не найдена |
| LuckyPants Dimensional Calibration Tool v9 | реальный исторический эталон и ремиксы для проблем первого/верхнего слоя | учитывать измеримость кромки, elephant foot и top surface | название «Truss Shrinkage Calibrator» не подтверждено |
| FDM Z-Dimensional Test | глубины от верхней базы, направляющая depth rod, повторная проверка | альтернативный Z-канал, менее зависимый от первого слоя | новый авторский эксперимент; автор называет его preliminary |
| ScanNTune | сканер, калибровка масштаба пластиковой картой, два скана под 90°, ring centers, отчёт об однозначности | самокалибровка measurement backend, neutral features, отказ при неоднозначности | XZ/YZ автор помечает experimental; CV не нужен в Lua MVP |
| OpenDesignCore / AI Parts on Demand | provenance, validation gates, measurement cards, сохранение сырых данных | архитектурные паттерны для воспроизводимости | не являются эталонами точности FDM |
| vcad | параметрическое CAD-представление, inspect/export/CLI/CI | пример проверяемой генерации артефактов | тезис про «единый measurement manifest» источником не подтверждён |

### 4.2. K3D Accuracy

Источник: [K3D Accuracy calibration](https://k3d.tech/calibrations/accuracy/) и
[история релизов](https://k3d.tech/calibrations/accuracy/releases/).

**Подтверждено:**

- K3D различает размеры, чувствительные и нечувствительные к equidistant correction;
- scale и постоянный контурный сдвиг оцениваются отдельно;
- пользователь может оптимизировать абсолютную, относительную или сбалансированную ошибку;
- предусмотрены варианты расчёта с equidistant correction и без неё;
- результат проверяется повторной печатью и сравнением before/after;
- автор отдельно напоминает сначала настроить принтер и процесс.

**Важная оговорка:** на текущей странице формула для equidistant correction в отображаемом
виде выглядит размерностно сомнительно. Если исходная модель записана как

```text
X = X0 × delta + 2 × Delta
```

то алгебраически должно быть:

```text
Delta = (X - X0 × delta) / 2
```

Поэтому конкретную формулу K3D нельзя слепо копировать. Полезен принцип разделения эффектов,
а не непроверенное выражение на странице.

### 4.3. Vector3D Califlower и Calilantern

Источник: [Calilantern Calibration Tool Mk2](https://vector3d.shop/products/calilantern-calibration-tool-mk2).

**Подтверждено публичным описанием:**

- web calculator ведёт пользователя через позиционирование и ввод;
- оцениваются size и skew;
- результат показывается графически;
- предусмотрен итерационный цикл с проверочной печатью;
- Calilantern переносит измерения в три плоскости.

Наиболее ценный урок — не конкретная геометрия, а UX: пользователь видит, что измеряет,
почему результат считается приемлемым и что изменится в профиле.

**Лицензионная граница:** коммерческие условия явно запрещают reverse engineering и
копирование. Это допустимый ориентир интерфейса и исследовательских вопросов, но не источник
геометрии, текста или реализации.

### 4.4. Fleur de Cali / Calistar

Источники:

- [репозиторий Fleur de Cali](https://github.com/dirtdigger/fleur_de_cali);
- [worksheet](https://github.com/dirtdigger/fleur_de_cali/blob/main/worksheet/docs/index.md);
- [calculator JavaScript](https://github.com/dirtdigger/fleur_de_cali/blob/main/worksheet/docs/javascript/calibration.js).

**Подтверждено:**

- модель параметрическая и строится CadQuery;
- доступны 2–5 измерительных уровней и размеры до 180 мм;
- измеряются внешние и внутренние X/Y, а также диагонали для skew;
- worksheet принимает до трёх повторов каждого измерения;
- вычисляются среднее, выборочная дисперсия и вклад точности штангенциркуля;
- достаточно заполнить только пригодную часть данных;
- интерфейс предупреждает, когда предлагаемая коррекция сравнима с шумом;
- проект лицензирован под GPL-3.0.

Здесь особенно полезны повторные измерения, сохранение сырья и честный вывод
«данных недостаточно для коррекции». Формулу uncertainty при этом не стоит переносить
механически: паспортная accuracy штангенциркуля не равна стандартному отклонению.

### 4.5. BoronTrident

Источники:

- [основная calibration documentation](https://github.com/cmdremily/BoronTrident/blob/master/calibration/README.md);
- [XY differential calibration](https://github.com/cmdremily/BoronTrident/blob/master/calibration/xy-differential-calibration.md);
- [advanced material calibration](https://github.com/cmdremily/BoronTrident/blob/master/calibration/adv-material-calibration.md).

**Подтверждено:**

- геометрия машины калибруется отдельно от усадки материала;
- разность длинного и короткого размеров используется для подавления общего аддитивного
  сдвига;
- измерение полностью повторяют пять раз с переустановкой инструмента;
- центральной оценкой служит медиана, подозрительные результаты перемеряются;
- в детали предусмотрены регистрационные поверхности для губок;
- протокол фиксирует охлаждение, seam, pressure advance, flow и проверочную печать.

Два сильных вывода для этого проекта:

1. повтор — это не пять чтений при неподвижных губках, а пять полных снятий и установок;
2. хорошая регистрация штангенциркуля может дать больше, чем простое утолщение балки.

Явная лицензия в репозитории при проверке не найдена. Текст и модели переносить не следует.

### 4.6. LuckyPants и AP Engineering

Раннее название «LuckyPants / AP Engineering Truss Shrinkage Calibrator» подтвердить не
удалось. Ближайшая реальная цепочка:

- [LuckyPants Dimensional Calibration Tool v9](https://www.thingiverse.com/thing%3A1982686);
- [републикация/ремикс AP Engineering](https://www.makeronline.com/en/model/Shrinkage%20Calculator%20-%20Dimensional%20Calibration%20Tool%20v9%20%28Made%20by%20LuckyPants%29/20741.html).

В ремиксах менялись фаски и измерительные кромки из-за elephant foot и качества верхнего
слоя. Это подтверждает важный практический тезис: эталон должен проектироваться не только
как жёсткая деталь, но и как однозначный интерфейс с губками штангенциркуля.

### 4.7. FDM Z-Dimensional Test

Источник: [FDM Z-Dimensional Test by jcdeshaies](https://thangs.com/designer/jcdeshaies/3d-model/FDM%2520Z-Dimensional%2520Test-1589673).

Автор измеряет глубины `40 / 60 / 80 / 100 мм` от общей верхней базы, использует
направляющую для depth rod и предлагает две исходные печати плюс третью проверочную.
Замысел — уменьшить влияние первого слоя, Z-offset и неровности стола.

Это интересная **гипотеза**, но пока не доказанный лучший Z-эталон. Сам автор называет
методику предварительной. Её нужно сравнить с внешними ступенями по удобству установки,
разбросу и чувствительности к дефектам верхней поверхности.

### 4.8. ScanNTune

Источник: [ScanNTune](https://github.com/jaak0b/ScanNTune).

**Подтверждено:**

- масштаб сканера калибруется объектом известного размера, например пластиковой картой;
- деталь сканируется дважды с поворотом на 90°, чтобы отделить X/Y искажения сканера;
- центры колец используются как признаки, менее чувствительные к ширине экструзии;
- результат сопровождается проверками качества и отказом при неоднозначности;
- XY workflow основной, XZ/YZ автор помечает experimental;
- лицензия MIT.

Для текущего Lua-плагина компьютерное зрение слишком сильно расширяет scope. Но архитектурно
полезно заранее допустить внешний measurement backend, который импортирует структурированный
результат вместе с версией, uncertainty и quality verdict.

### 4.9. Соседние проекты

[OpenDesignCore](https://github.com/thewriterben/OpenDesignCore) и
[AI Parts on Demand](https://github.com/AlakazipLabs/ai-parts-on-demand) полезны идеями
provenance, validation/refusal gates, карточек измерений и хранения исходных данных. Они не
являются источниками метрологических допусков.

[vcad](https://github.com/ecto/vcad) демонстрирует проверяемый parametric CAD pipeline с
inspect/export/CLI/CI. Раннее утверждение, будто vcad уже реализует единый источник геометрии
и measurement manifest, не подтвердилось. Для `dimensional-accuracy` единая спецификация
всё равно разумна, но это наше инженерное решение.

## 5. Что говорит PrusaSlicer

### 5.1. Shrinkage

Источники:

- [ShrinkageCompensation.cpp](https://github.com/prusa3d/PrusaSlicer/blob/master/src/libslic3r/ShrinkageCompensation.cpp);
- [ConfigDefsFDM.cpp](https://github.com/prusa3d/PrusaSlicer/blob/master/src/libslic3r/ConfigDefsFDM.cpp).

PrusaSlicer интерпретирует shrinkage `p` в процентах через scale factor

```text
F(p) = 100 / (100 - p)
```

и поясняет это примером: если ожидаемые 100 мм превратились в 99 мм, вводится 1%.
Отсюда при нулевом baseline и наблюдаемом slope `a`:

```text
p_new = 100 × (1 - a)
```

Если в профиле уже было `p_current`, корректная итерационная формула:

```text
p_new = 100 - a × (100 - p_current)
```

Следовательно, текущая zero-baseline формула проекта верна, но UI должен явно показывать
прочитанное исходное значение и итоговую формулу.

### 5.2. XY size compensation

Источник: [PrintObjectSlice.cpp](https://github.com/prusa3d/PrusaSlicer/blob/master/src/libslic3r/PrintObjectSlice.cpp).

`xy_size_compensation` — геометрический offset контуров при slicing, а не усадка материала.
Если предположить модель

```text
measured = s × (nominal + 2c) + b
```

то компенсация внешнего размера, обнуляющая intercept, равна:

```text
c = -b / (2s)
```

Формула текущего calculator поэтому внутренне согласована. Но fit по одним внешним размерам
не доказывает, что найденный `b` действительно является контурной ошибкой. В него также
могут попасть seam, blob, установка губок, сила измерения, прогиб, roughness, flow/PA и
систематическая ошибка инструмента.

**Решение:** до отдельного precision-эталона называть `b` «наблюдаемым аддитивным членом»,
а `xy_size_compensation` — диагностической рекомендацией, не автоматически установленной
причиной.

Дополнительная внешняя проверка концепции: документация OrcaSlicer также разделяет
[filament shrinkage](https://github.com/OrcaSlicer/OrcaSlicer/wiki/material_basic_information)
и процессные [hole/contour compensation](https://github.com/orcaslicer/orcaslicer/wiki/tolerance_calib).

## 6. Ограничения текущей математики

### 6.1. Три точки — это очень мало

Для `N = 40, 80, 120` и модели

```text
m = sN + b
```

OLS-slope упрощается до:

```text
s = (m120 - m40) / 80
```

Среднее измерение `m80` вообще не влияет на slope. Оно в основном проверяет, лежит ли
середина на прямой между крайними точками:

```text
curvature_hint = m80 - (m40 + m120) / 2
```

У M1 два параметра и три наблюдения, то есть одна остаточная степень свободы. Красивый RMS
на таком наборе — слабое доказательство адекватности модели. Leave-one-out для трёх точек
полезен как diagnostic, но не является независимой валидацией.

### 6.2. Нужны как минимум две модели

```text
M0: m_i = s × N_i + e_i
M1: m_i = s × N_i + b + e_i
```

M1 следует предпочитать не просто при меньшем RMS, а когда:

- величина `b` заметно превосходит uncertainty измерения;
- знак и порядок `b` повторяются на независимых печатях;
- correction улучшает проверочную деталь;
- альтернативная измерительная топология подтверждает аддитивный эффект.

Если эти условия не выполнены, безопаснее рекомендовать только scale или вообще не
рекомендовать изменение.

### 6.3. Precision-модель должна кодировать чувствительность геометрии

Обобщённая модель:

```text
m_i = s × N_i + k_i × c + e_i
```

где:

- `k = 0` — размер по нейтральным/центровым признакам;
- `k = +2` — внешний размер при идеализированном радиальном contour offset;
- `k = -2` — внутренний размер;
- другие значения допустимы только если следуют из геометрии и slicing pipeline.

Это создаёт идентифицируемость scale и contour term. Одни внешние размеры разной длины
математически могут оценить intercept, но не подтверждают его физическую природу.

### 6.4. X и Y нельзя объединять по фиксированному порогу

Текущий порог anisotropy полезен как guardrail, но решение об общем XY shrinkage лучше
принимать по разности, сопоставленной с её uncertainty:

```text
|s_x - s_y| <= k × u(s_x - s_y)
```

где `k` и метод оценки uncertainty должны быть зафиксированы протоколом. До появления
реальных данных лучше показывать X и Y отдельно и явно объяснять, почему PrusaSlicer может
требовать одно общее значение.

## 7. Измерительная неопределённость без ложной точности

Источники:

- [NIST: Measurement Uncertainty](https://www.nist.gov/itl/sed/topic-areas/measurement-uncertainty);
- [NIST: Gauge R&R study](https://www.itl.nist.gov/div898/handbook/mpc/section4/mpc46.htm);
- [BIPM/JCGM Guides](https://www.bipm.org/en/publications/guides).

Нельзя без оговорок складывать

```text
variance = caliper_accuracy² + repeatability_variance / n
```

Паспортная accuracy или MPE обычно является границей ошибки, а не стандартным отклонением.
Чтобы превратить её в standard uncertainty, нужно явно выбрать распределение и обосновать
предположение. Например, модель равномерной ошибки `±a` даёт `u = a / sqrt(3)`, но это
именно допущение, а не универсальный факт.

На первом этапе лучше хранить раздельно:

- resolution инструмента;
- manufacturer MPE/accuracy;
- within-operator repeatability;
- between-operator variation;
- between-caliper variation;
- print-to-print variation;
- fit residual;
- model/geometry uncertainty.

В интерфейсе достаточно честного вывода диапазонов и флагов. Weighted least squares следует
вводить только после того, как variance model подтверждена данными.

## 8. Как собирать повторные измерения

Для каждой позиции:

1. полностью снять штангенциркуль;
2. заново поставить губки в обозначенные регистрационные поверхности;
3. снять 3–5 показаний;
4. сохранить все исходные значения;
5. отметить slip, неоднозначную посадку, повреждение кромки или явную ошибку чтения;
6. никогда не удалять выброс автоматически.

Показывать:

- `n`;
- median и mean;
- min/max и range;
- sample SD;
- MAD;
- отдельно введённую характеристику инструмента.

До накопления данных разумная центральная оценка для fit — median. Подозрительное значение
нужно подсветить и предложить перемерить; исключать его можно только явным действием
пользователя с сохранением audit trail.

## 9. Открытые вопросы и экспериментальный протокол v1

### 9.1. Область протокола

Протокол v1 выбирает **измерительную геометрию**, а не доказывает точность всей
калибровочной цепочки. Он должен ответить на два вопроса:

1. можно ли воспроизводимо установить штангенциркуль на рабочие поверхности;
2. сохраняется ли результат между независимыми печатями.

Он не должен одновременно подбирать профиль, доказывать причинную природу intercept или
оценивать качество автоматического apply. Зависимости исследований:

```text
handling repeatability
→ print-to-print repeatability
→ идентифицируемость модели
→ correction trial
→ holdout/generalization trial
```

Переход к следующему звену разрешён только после фиксации результата предыдущего.

### 9.2. Реестр открытых вопросов

| ID | Вопрос или опровержимая гипотеза | Какие данные нужны | Заранее определённое решение |
|---|---|---|---|
| `XY-H1` | Сечение `7 × 5 мм` уменьшает ошибку повторной установки относительно `6.5 × 4.5 мм` | Gate A и B для существующих XY control/challenger | заменить release-геометрию только при прохождении строгих gates и практически значимом преимуществе; при эквивалентности оставить меньшую |
| `XY-H2` | Регистрационные элементы для губок полезнее простого утолщения | новый versioned prototype и новый парный trial с control | проектировать только как отдельный challenger; не делать вывод по BoronTrident без собственного опыта |
| `XY-H3` | Рабочие поверхности одинаково удобны для X40/X80/X120 и Y40/Y80/Y120 | cell-level failure, range, SD и MAD | любой систематически худший span требует локальной переработки, даже если pooled metric хороший |
| `XY-M1` | Наблюдаемый intercept устойчив между независимыми печатями | минимум 3 baseline prints, fit каждой печати и interval между ними | не рекомендовать contour correction, если знак или practically relevant magnitude не воспроизводятся |
| `XY-M2` | M1 объясняет данные лучше M0 настолько, что дополнительный параметр полезен | independent prints, uncertainty и verification outcome | оставить M0, если выигрыш M1 сравним с шумом или не подтверждается correction trial |
| `XY-C1` | Одно общее XY shrinkage допустимо | uncertainty разности `s_x-s_y` на независимых печатях | объединять оси только если observed difference неразличима на выбранном engineering margin |
| `Z-H1` | Z-C40 даёт более повторяемое измерение 40 мм, чем Z-B | matched Z40 Gate A и B | строить полный Z-C `40/80/120` только после прохождения обоих gates |
| `Z-H2` | Depth Z менее чувствителен к first-layer/datum error, чем external Z | отдельный depth prototype, операторы, инструменты и независимые печати | не добавлять в plugin до прямого matched trial; текущая публикация — только источник гипотезы |
| `U-1` | Главная измерительная компонента — jaw placement, а не caliper или operator bias | crossed operator × caliper Gate A | при dominant operator/caliper effect улучшать инструкцию и fixtures до solver-а |
| `V-1` | Предлагаемая коррекция улучшает повторную печать больше combined uncertainty | минимум 3 baseline и 3 verification prints | не ставить `VERIFIED`, если improvement не превышает заранее выбранный margin |
| `V-2` | Коррекция обобщается за пределы размеров, использованных для fit | отдельный holdout artifact/feature | не заявлять generalization по повтору того же `40/80/120` эталона |

Статус каждого вопроса должен быть одним из:

```text
UNTESTED / PROTOCOL_LOCKED / RUNNING / SUPPORTED / NOT_SUPPORTED / INCONCLUSIVE
```

`SUPPORTED` означает только поддержку в границах конкретного protocol, material и process
signature. Оно не означает универсальную истинность.

Пока в репозитории нет физических raw results, все вопросы имеют статус `UNTESTED`, а сам
v1 остаётся `DRAFT`. Статус `PROTOCOL_LOCKED` появляется только после создания frozen
execution copy и устранения расхождений с `prototypes/README.md`.

### 9.3. Что физически существует сейчас

Исполнимый v1 не должен упоминать ещё не созданные модели как участников эксперимента.

| Код в trial | Файл/модель | Роль | Сравниваемые признаки |
|---|---|---|---|
| `XY-C` | release XY-A, `6.5 × 4.5 мм` | control | X40/X80/X120/Y40/Y80/Y120 |
| `XY-T` | `dimensional_accuracy_xy_7x5.stl` | challenger | те же шесть spans |
| `Z-B` | release stepped Z-B | control | Z40; Z80/Z120 только supporting data |
| `Z-C40` | `dimensional_accuracy_zc40.stl` | challenger | только matched Z40 |

Caliper-registration XY и depth Z пока являются вопросами `XY-H2` и `Z-H2`, а не
участниками v1. Когда их геометрия появится, ей нужны отдельные artifact ID/revision и новый
парный запуск с новым control, напечатанным в том же эксперименте.

### 9.4. Что фиксируется до первой печати

Перед запуском создаётся неизменяемый `protocol.md` с:

- `trial_id` и версией протокола;
- выбранными вопросами из реестра;
- точными artifact ID, revision и SHA-256 STL;
- commit плагина и исходников моделей;
- PrusaSlicer version/commit;
- printer, firmware, nozzle и physical extruder/material slot;
- spool brand, polymer, colour и lot;
- полными идентификаторами printer/print/filament preset;
- layer height, line width, walls, top/bottom layers, infill, seam, flow/PA и температурами;
- исходными shrinkage/contour settings;
- раскладкой и координатами на столе;
- временем минимального охлаждения;
- списком operators и calipers;
- random seed и готовым порядком измерений;
- primary metrics, provisional margins и stop rules.

Этот раздел задаёт дизайн исследования, но не должен быть единственной execution copy.
Перед реальным запуском его точная версия переносится в
`prototypes/results/<trial-id>/protocol.md`. Если исследовательская записка, текущий
`prototypes/README.md` и frozen protocol расходятся, действителен только frozen protocol,
а trial не получает `PROTOCOL_LOCKED`, пока расхождения не устранены.

Для geometry-selection trial выбранные XY/Z shrinkage и contour compensation должны быть
нулевыми. Если это невозможно, их фактические значения фиксируются, но такой запуск нельзя
смешивать с zero-baseline результатами.

После начала печати нельзя менять формулы, пороги или правила исключения строк. Любое
изменение создаёт новую версию protocol и новый trial ID.

### 9.5. Контролируемые, рандомизируемые и записываемые факторы

**Фиксировать одинаковыми:**

- printer, nozzle, spool/lot, slicer build и все preset values;
- orientation, seam strategy и cooling interval;
- метод контакта губок и положение по высоте рабочей поверхности;
- отсутствие post-processing: не шлифовать и не подрезать кромки.

**Рандомизировать или балансировать:**

- порядок control/challenger;
- порядок spans;
- порядок operator/caliper blocks;
- левую/правую или переднюю/заднюю позицию парных моделей на столе между print batches.

**Только записывать, не «исправлять» во время trial:**

- ambient temperature/humidity;
- фактическое время после окончания печати;
- zero drift инструмента;
- видимые seam/blob/elephant-foot/top-surface defects;
- failed, slipped или ambiguous installation;
- protocol deviation.

Настройка flow, PA или температуры во время trial делает последующие данные другим
экспериментом.

### 9.6. Gate 0 — готовность

До печати:

1. Выполнить `make verify-all`; сохранить вывод и commit.
2. Сохранить SHA-256 STL, 3MF/project и каждого G-code.
3. Экспортировать или иным способом зафиксировать полные preset values.
4. Подписать физические образцы слепыми кодами, например `A` и `B`; таблицу соответствия
   хранить отдельно до окончания ввода.
5. Сфотографировать ориентацию моделей и правильную установку губок для каждого feature.
6. Сгенерировать полный `schedule.csv` с observation IDs до измерений.
7. Очистить губки, проверить свободный ход, записать resolution, stated MPE/accuracy,
   serial/asset ID и calibration status каждого caliper.
8. Проверить zero до начала; не округлять сверх отображаемого прибором разряда.

Печать или session не допускается к анализу, если невозможно восстановить её STL/G-code,
process signature или соответствие физического образца print ID.

### 9.7. Gate A — handling and measurement repeatability

#### Дизайн

Печатать одну свежую пару control/challenger в одном batch для XY и отдельную пару для Z.
Измерять после одинакового охлаждения, не ранее зафиксированного в protocol момента.

Минимум:

- 2 независимых оператора;
- 3 штангенциркуля для полного v1;
- 10 полных установок на каждую комбинацию
  `model × feature × operator × caliper`;
- шесть matched spans для XY;
- matched Z40 для Z.

Полный объём:

```text
XY: 2 models × 6 spans × 2 operators × 3 calipers × 10 = 720 attempts
Z:  2 models × 1 span  × 2 operators × 3 calipers × 10 = 120 attempts
```

Если доступны только два calipers, можно выполнить exploratory pilot объёмом 480/80
attempts. Он полезен для выявления грубых проблем, но не получает полный v1 PASS и не
подтверждает вывод о between-caliper variation.

#### Порядок измерений

Для каждой пары `operator × caliper` XY schedule состоит из десяти rounds. В одном round
каждая из 12 комбинаций `blind model × feature` встречается ровно один раз в случайном
порядке. После пяти rounds делается перерыв и zero check; затем выполняются ещё пять rounds
с новым порядком. Так десять касаний одного span не выполняются подряд и не превращаются в
тренировку поиска запомненного числа.

Для Z один round содержит две переставленные случайным образом модели на Z40; всего
десять rounds. Порядок шести `operator × caliper` blocks балансируется циклически, чтобы
один инструмент или оператор не оказывался всегда первым или последним.

Randomization генерируется один раз из seed в frozen protocol. Ручная перестановка допустима
только как записанное deviation.

#### Один attempt

1. Взять закрытый observation ID из schedule.
2. Проверить правильный blind specimen, feature и caliper.
3. Полностью убрать инструмент от детали.
4. Закрыть/открыть губки и заново установить их по инструкции.
5. Не искать движением «красивое» или ожидаемое значение.
6. Если установка однозначна, записать ровно показание дисплея.
7. Если губки соскользнули или контакт неоднозначен, записать status и оставить
   `measured_mm` пустым; не заменять attempt новой строкой.
8. Перейти к следующему элементу schedule.

Оператор не должен видеть предыдущие значения той же серии, если запись может выполнять
второй человек или простая форма. Геометрия всё равно может раскрыть вариант, поэтому trial
не считается полностью blind.

#### Blocks и zero checks

Один block не должен превышать примерно 60 attempts без перерыва. Zero записывается:

- до block;
- после block;
- немедленно после падения инструмента или подозрения на загрязнение.

Если изменение zero превышает один display resolution, block получает
`ZERO_CHECK_FAILED`. Его можно повторить после очистки и обнуления только как новый block;
исходные строки остаются в наборе.

### 9.8. Gate B — print-to-print repeatability

К Gate B допускается control и challenger, который прошёл строгий Gate A или дал
`INCONCLUSIVE`, полезный для подтверждения. Явно худший challenger дальше не печатается.

Дизайн:

- минимум 3 независимых print batches, включая batch Gate A;
- в каждом batch печатать matched control/challenger;
- полностью завершать и охлаждать один batch до начала следующего;
- использовать тот же approved slicing setup;
- балансировать позиции моделей на столе между batches;
- один заранее назначенный operator и caliper;
- 5 полных re-seat на каждый feature каждой physical copy;
- рандомизировать порядок copies, models и spans.

Минимальный объём для трёх batches:

```text
XY: 2 models × 3 prints × 6 spans × 5 = 180 attempts
Z:  2 models × 3 prints × 1 span  × 5 =  30 attempts
```

Gate B отделяет print-to-print variation от handling variation, уже оценённой в Gate A.
Он не оценивает другого оператора или инструмент повторно.

### 9.9. Stop rules и недействительные данные

Ничего не удаляется из raw data. Вместо этого используются статусы.

| Ситуация | Действие |
|---|---|
| working face повреждена или пересечена тяжёлым print defect | пометить print invalid; сфотографировать; перепечатать всю matched pair новым batch ID |
| напечатан неверный preset или ненулевой baseline вопреки protocol | весь batch invalid; сохранить как protocol deviation |
| zero drift больше одного resolution | block invalid; очистить/обнулить и повторить новым block ID |
| failed/slipped/ambiguous jaw placement | одна запланированная попытка с пустым measurement; не делать скрытую замену |
| transcription error | добавить новую строку с `supersedes_observation_id`; исходную не менять |
| оператор нарушил порядок | сохранить фактический порядок и deviation; не переставлять строки задним числом |
| отсутствует planned observation | оставить пропуск с причиной; не уменьшать denominator failure rate |

Visible cosmetic defect вне working surfaces записывается, но сам по себе не исключает print.

### 9.10. Структура результатов

Рекомендуемый каталог:

```text
prototypes/results/<trial-id>/
  protocol.md
  environment.json
  artifacts.csv
  prints.csv
  instruments.csv
  schedule.csv
  measurements.csv
  analysis.md
  checksums.sha256
  photos/
```

`protocol.md`, `schedule.csv` и checksums замораживаются до измерений. Производные таблицы
не заменяют `measurements.csv`.

Минимальная строка `measurements.csv`:

```text
observation_id
trial_id
protocol_version
gate
session_id
block_id
scheduled_order
actual_order
print_batch_id
print_id
blind_model_id
artifact_id
artifact_revision
operator_id
caliper_id
axis
feature_id
measurement_method
nominal_mm
repetition
zero_before_mm
zero_after_mm
measured_mm
installation_status
failure_reason
elapsed_since_print_h
notes
supersedes_observation_id
```

Допустимые `installation_status`:

```text
OK
INSTALL_FAILED
SLIPPED
AMBIGUOUS_CONTACT
EDGE_DEFECT
ZERO_CHECK_FAILED
SKIPPED
TRANSCRIPTION_ERROR
```

STL/G-code hashes, bed position, environment и preset snapshot хранятся в связанных таблицах,
а не перепечатываются вручную в каждой measurement row.

### 9.11. Расчёты Gate A

Для каждой cell
`model × feature × operator × caliper` показывать без исключения строк:

- scheduled, valid и failed counts;
- failure rate;
- median, mean, min/max и range;
- sample SD;
- MAD и `1.4826 × MAD`;
- raw dot/strip plot в порядке наблюдения.

Чтобы отделить placement noise от постоянного operator/caliper shift, для каждого
`model × feature` считать pooled within-cell SD:

```text
s_within =
sqrt(
  sum_g((n_g - 1) × s_g²)
  /
  sum_g(n_g - 1)
)
```

где `g` — отдельная operator/caliper cell. Отдельно показывать:

- максимальную разность operator medians при прочих matched factors;
- максимальную разность caliper medians;
- candidate-control median shift;
- отношение `s_within(candidate) / s_within(control)`.

Co-primary outcomes Gate A:

1. installation failure по strict rule;
2. прохождение `0.03 мм` cell-range gate;
3. worst-span `s_within` для каждого model.

Для comparative ratio строится 90% stratified bootstrap interval: внутри каждой
operator/caliper cell с возвращением выбирается исходное количество valid measurements,
затем заново вычисляются `s_within` и candidate/control ratio. Используется 10 000
iterations и заранее записанный random seed. Failed attempts не превращаются в числа:
failure rate анализируется отдельно.
Bootstrap interval является описанием устойчивости небольшого опыта, а не заменой
independent prints.

Если SD упирается в quantization прибора, нельзя объявлять улучшение по отношению
`0/0`. Оба результата помечаются как indistinguishable at instrument resolution.

### 9.12. Расчёты Gate B

Сначала получить median пяти re-seat для каждого
`print × model × feature`. Затем для каждого `model × feature` показать:

- три per-print medians;
- их range и sample SD;
- bias относительно nominal только как descriptive value;
- matched candidate-control shift внутри каждого batch;
- для XY — per-print `s_x`, `b_x`, `s_y`, `b_y` и curvature hints.

Gate B нельзя «улучшить» объединением всех raw placements в одну большую regression:
экспериментальной единицей для print-to-print вывода является physical print, а не отдельное
касание губок.

### 9.13. Заранее фиксируемые критерии решения

В репозитории уже указан строгий provisional порог `0.03 мм`. В v1 он сохраняется для
сопоставимости, но не выдаётся за метрологический стандарт.

#### Strict prototype-selection gate

Challenger проходит Gate A, только если:

- нет failed/slipped/ambiguous installation;
- range каждой десятикратной cell не больше `0.03 мм`;
- нет zero-invalid blocks в анализируемом наборе;
- matched candidate-control shift не превышает `0.03 мм` ни на одном feature.

Он проходит Gate B, только если:

- каждая physical copy измерима без installation failure;
- range трёх per-print medians не больше `0.03 мм` на каждом feature;
- matched candidate-control shift остаётся в пределах `0.03 мм`.

Если strict gate провален из-за одного события, это не превращает все данные в мусор:
результат остаётся `NOT_SUPPORTED` или `INCONCLUSIVE` и используется для следующего
прототипа.

#### Comparative decision

Помимо strict gate, challenger называется **практически лучше**, только если:

- `s_within` уменьшился не менее чем на 20% минимум на четырёх из шести XY spans;
- ни один span не ухудшился более чем на 20%;
- failure rate не хуже control;
- operator/caliper shifts не стали больше;
- преимущество сохраняется в Gate B;
- цена улучшения по print time/material признана приемлемой до раскрытия blind codes.

Если модели неразличимы на resolution инструментов или confidence interval охватывает как
заметное улучшение, так и ухудшение, результат — `INCONCLUSIVE`, а не PASS.

Для comparative PASS верхняя граница 90% bootstrap interval отношения `s_within` должна
быть меньше `1.0` хотя бы на четырёх spans. При трёх print batches Gate B слишком мал для
надёжного bootstrap по prints; там показываются все три matched outcomes, и расхождение
направления эффекта автоматически даёт `INCONCLUSIVE`.

Для Z с единственным matched span practically better означает point ratio
`s_within(Z-C40) / s_within(Z-B) <= 0.8`, верхнюю границу его 90% interval меньше `1.0`
и одинаковое направление преимущества во всех трёх Gate B batches.

При эквивалентной повторяемости выбирается меньшая и более быстрая release-геометрия. Один
только меньший material use не может спасти вариант, проваливший strict gate.

Значения `0.03 мм` и `20%` — **pre-registered engineering margins v1**, а не внешние
стандарты. После первого полного pilot их можно изменить только для следующей версии
protocol с опубликованным обоснованием; нельзя пересчитать тот же trial новым порогом и
выдать это за первоначальный PASS.

### 9.14. Решение после v1

| Результат | Следующее действие |
|---|---|
| `XY-T` проходит strict и comparative gates | кандидат на release replacement после отдельного correction trial |
| `XY-T` эквивалентен `XY-C` | оставить `XY-C`; перейти к caliper-registration prototype |
| оба XY варианта проваливают handling gate | сначала переработать working faces/registration, не solver |
| Gate A хороший, Gate B плохой | исследовать print process/geometry sensitivity и увеличить independent-print coverage |
| `Z-C40` проходит оба gates | строить versioned Z-C `40/80/120`, затем повторить полный trial |
| `Z-C40` не лучше Z-B | оставить Z-B и проверить отдельную depth-гипотезу |
| operator/caliper shift доминирует placement noise | стандартизировать инструкцию, contact force и fixtures |
| все эффекты меньше resolution | нужен более подходящий measurement backend; больше повторов не создают недостающую resolution |

### 9.15. Что v1 не доказывает

Даже успешный v1 не подтверждает:

- что intercept является contour error;
- что shrinkage одинаков для другого filament lot, цвета, orientation или profile;
- что коррекция улучшает размер;
- что результат обобщается на отверстия, посадки и произвольные детали;
- что `0.03 мм` является корректным user-facing acceptance threshold.

Для correction validation нужны минимум три независимые baseline prints и три независимые
verification prints выбранного артефакта. Повтор того же артефакта проверяет
воспроизводимость; holdout с другими размерами или геометрией проверяет обобщение.

Коррекция получает статус `VERIFIED` только если:

1. improvement больше заранее оценённой combined uncertainty;
2. ни один критичный размер не ухудшился за установленный margin;
3. эффект повторяется на независимых prints;
4. process signature и artifact revision полностью восстановимы.

## 10. Моё видение продукта

### 10.1. Область обещания

Плагин калибрует не «принтер вообще», а конкретную process signature:

```text
printer + nozzle + filament/material + print preset
+ orientation + slicer version + artifact revision
```

Результат вне этой комбинации — гипотеза, пока не выполнена повторная проверка.

### 10.2. Два XY-режима

**Quick XY**

- текущий компактный внешний эталон;
- 3–5 повторов каждой позиции;
- надёжная оценка scale;
- intercept показывается как diagnostic;
- быстрый preview и verification;
- минимум времени и материала.

**Precision XY**

- отдельный артефакт с neutral и contour-sensitive признаками;
- возможно сочетание outer/inner/center geometry;
- независимая оценка scale и contour term;
- больше времени печати и более строгий measurement protocol;
- доступен только после физической валидации геометрии.

Quick не должен притворяться Precision. Это два разных уровня доказательности.

### 10.3. Z остаётся experimental дольше

Z сильнее зависит от первого слоя, стола, top surface, целочисленного числа слоёв и способа
измерения. External Z и Depth Z следует показывать как разные методы, пока эксперимент не
установит область применимости каждого.

### 10.4. Отдельные задачи — отдельные модули

Не включать в один solver:

- machine geometry/skew;
- material shrinkage;
- contour/hole compensation;
- hole/shaft fit;
- flow и pressure advance;
- scanner/computer vision backend.

Они могут обмениваться одним форматом результата, но требуют разных эталонов и причинных
моделей.

## 11. UX результата

### 11.1. Workflow state и качество — разные оси

Предлагаемые состояния процесса:

```text
INVALID_INPUT
MEASURED
ESTIMATED
CORRECTION_SUPPORTED
APPLY_ATTEMPTED
APPLY_CONFIRMED
VERIFIED
```

Отдельно severity:

```text
PASS / WARN / FAIL
```

Вызов setter без readback не означает `APPLY_CONFIRMED`. Хороший fit без проверочной
печати не означает `VERIFIED`.

### 11.2. Preview — основной сценарий

До любой записи показать единый план:

- какой printer/filament/print preset прочитан;
- какие baseline compensation уже установлены;
- какая модель выбрана и почему;
- сырые и агрегированные измерения;
- рассчитанный diff;
- warnings и блокирующие причины;
- что именно будет изменено.

Проверить весь XY/Z-план до первой записи. После записи сделать readback и сообщить отдельно,
удалось ли изменить конфигурацию и относится ли она к реально нарезаемому профилю.

### 11.3. Отказ — полноценный результат

Плагин должен уметь закончить анализ фразами:

- «данных недостаточно»;
- «разброс измерений больше предлагаемой коррекции»;
- «scale устойчив, additive term не подтверждён»;
- «X и Y различаются сильнее измерительной неопределённости»;
- «применение выполнено, но не подтверждено readback»;
- «улучшение на verification print не доказано».

Это повышает доверие сильнее, чем обязательная выдача числа.

## 12. Единая спецификация артефакта

Сейчас номиналы и предположения повторяются между OpenSCAD, Lua, verifier, Makefile и
документацией. Нужен маленький machine-readable manifest, например:

```json
{
  "artifact_id": "DA-XY-Q1",
  "revision": 1,
  "method": "outer_jaws",
  "measurements": [
    {
      "id": "x40",
      "axis": "x",
      "nominal_mm": 40.0,
      "contour_coefficient": 2.0,
      "repeat_protocol": "full_reseat"
    }
  ]
}
```

Из него должны следовать или им проверяться:

- SCAD constants;
- Lua labels и nominal values;
- verifier expectations;
- measurement CSV/JSON template;
- metadata release-артефакта.

Необязательно сразу строить большой code generator. Сначала достаточно manifest + CI check,
который обнаруживает расхождение. `artifact_id/revision` должны присутствовать на модели,
в логе, сырых данных и результате.

## 13. Формат данных

Локальный JSON/CSV полезнее ранней community database. Минимальная запись:

```text
schema_version
plugin/solver version
artifact id/revision
PrusaSlicer version
printer/nozzle
filament/material identifiers
print/filament/printer preset identifiers or hashes
baseline compensation
raw repeated measurements
instrument metadata
operator/session id (псевдоним допустим)
fit candidates and diagnostics
recommended changes
apply/readback status
verification measurements
```

Сначала формат должен позволить повторить расчёт локально. Публикация и агрегация имеют
смысл только после стабилизации схемы, протокола и лицензии данных.

## 14. Исследовательские решения

### Делать сейчас

- завершить безопасный preview/apply каркас;
- добавить repeated input и хранение raw values;
- физически сравнить существующие XY control/challenger, затем отдельным trial проверить
  caliper-registration prototype;
- провести Z handling test;
- явно сравнивать M0 и M1;
- переименовать intercept в observed additive term;
- добавить artifact revision и structured local result;
- определить verification success относительно uncertainty.

### Делать после данных

- precision XY с разной contour sensitivity;
- uncertainty-aware объединение X/Y;
- calibrated thresholds вместо произвольных constants;
- внешний measurement backend;
- holdout artifact;
- machine/skew и fit modules.

### Пока не делать

- weighted solver без валидированной variance model;
- автоматическое удаление выбросов;
- автоматический `xy_size_compensation` из одного внешнего эталона;
- computer vision внутри Lua-плагина;
- большой community cloud;
- один all-in-one эталон для всех причин ошибки;
- обещание метрологической точности по красивому RMS трёх точек.

## 15. Правила дальнейшей исследовательской работы

### 15.1. Нормативные слова

В этом разделе:

- **MUST** — условие, без которого изменение не считается исследовательски завершённым;
- **MUST NOT** — запрещённый способ получить или представить результат;
- **SHOULD** — правило, от которого можно отступить, если причина записана;
- конкретные числа и реализации относятся к versioned protocol, а не к вечным правилам.

Эти правила применяются к новым изменениям. Они не требуют немедленно переписать весь
существующий код, но любая затронутая область должна быть доведена до них в том же изменении.

### 15.2. Обязательные правила

| ID | Уровень | Правило |
|---|---|---|
| `R-EVIDENCE-01` | MUST | Любое утверждение о физической причине, преимуществе геометрии или пригодности correction должно ссылаться на versioned protocol, immutable raw data и воспроизводимый analysis. Без этого оно остаётся гипотезой. |
| `R-PROTOCOL-01` | MUST | До первой печати фиксируются вопросы, артефакты, process signature, schedule/random seed, метрики, формулы, margins, stop rules и правила исключения. |
| `R-RAW-01` | MUST NOT | Нельзя удалять, перезаписывать, округлять задним числом или молча заменять raw observation. Исправление добавляется новой записью со ссылкой на исходную. |
| `R-VERSION-01` | MUST | Изменение геометрии, solver-а, protocol, data schema или decision margin получает новую соответствующую revision/version. Старые результаты остаются привязаны к прежней версии. |
| `R-RETRO-01` | MUST NOT | Новый порог или новая формула не могут задним числом превратить завершённый trial в первоначальный PASS. Допустим отдельный явно помеченный re-analysis. |
| `R-ANALYSIS-01` | MUST | Изменение математической модели, uncertainty propagation или threshold сопровождается выводом формул, областью допущений и synthetic/property tests. |
| `R-ERROR-01` | MUST | До причинной интерпретации коэффициента составляется error budget и перечисляются альтернативные источники того же наблюдаемого эффекта. |
| `R-SLICER-01` | MUST | Перед чтением или записью PrusaSlicer setting проверяются его единицы, диапазон, владелец preset, baseline semantics, порядок преобразований, API-доступность и возможность readback. |
| `R-APPLY-01` | MUST | Apply остаётся отделён от calculation: полный preview до первой записи, явное подтверждение, write/readback и отдельный статус неподтверждённого применения. |
| `R-VERIFY-01` | MUST | Статус `VERIFIED` требует независимых verification prints и improvement больше заранее заданного uncertainty/margin. Повтор того же артефакта не выдаётся за holdout generalization. |
| `R-PROVENANCE-01` | MUST | Для внешней идеи сохраняются первичный источник, дата проверки, лицензия и граница использования. При неизвестной лицензии допускается только независимо реализованный общий принцип. |
| `R-DECISION-01` | MUST | Изменения geometry, model, threshold, protocol или maturity status записываются в decision log вместе с альтернативами, evidence и условием пересмотра. |
| `R-SCOPE-01` | MUST NOT | Нельзя объединять machine geometry, material shrinkage, contour, hole/fit, flow/PA и measurement-backend errors в одну причинную модель без признаков, которые делают эффекты идентифицируемыми. |
| `R-REFUSAL-01` | MUST | Недостаток данных, неоднозначная модель, failed readback или improvement на уровне шума должны уметь завершать workflow без рекомендации или PASS. |

### 15.3. Рекомендуемые правила

- **SHOULD:** сначала проводить минимальный эксперимент, способный изменить решение, а не
  полный factorial «на всякий случай».
- **SHOULD:** хранить отрицательные и inconclusive результаты наравне с успешными, чтобы не
  повторять отвергнутые варианты.
- **SHOULD:** публиковать raw plots и per-print outcomes рядом с агрегатами; одно среднее или
  RMS не должно скрывать структуру данных.
- **SHOULD:** отделять exploratory pilot от confirmatory trial и явно маркировать переход
  между ними.
- **SHOULD:** выбирать measurement resolution и число независимых prints исходя из
  practically relevant correction, а не только из удобства сбора данных.
- **SHOULD:** сохранять возможность полностью повторить расчёт без PrusaSlicer UI из
  structured local result.
- **SHOULD:** оставлять Quick workflow простым; Precision-функции добавлять отдельным режимом,
  если они требуют другой геометрии или протокола.

### 15.4. Gates для типов изменений

| Изменение | Что обязательно предоставить до принятия |
|---|---|
| Рабочая поверхность, сечение или новый эталон | новый artifact ID/revision; обновлённая спецификация; STL verification; handling Gate A; затем print-to-print Gate B |
| Номиналы или measurement features | обоснование идентифицируемости; manifest/verifier/UI sync; новая artifact revision; несовместимость со старыми данными отмечена |
| Solver или формула correction | analytical note; assumptions; synthetic/property tests; solver version; сравнение со старым результатом на frozen fixtures |
| Threshold или quality verdict | источник margin; sensitivity analysis; новая protocol/solver version; запрет ретроактивного PASS |
| Uncertainty model или weighting | описание каждой variance component; единицы и distribution assumptions; validation на физических данных |
| PrusaSlicer setting или apply workflow | settings-semantics matrix; проверка исходного кода/документации; baseline cases; preview diff; write/readback и manual host test |
| Measurement protocol | новая protocol version; rationale; updated schedule/schema; данные разных версий не pool-ятся без явной модели |
| Формат данных | новый `schema_version`; compatibility note или migration; возможность пересчитать прежний результат сохраняется |
| Внешняя идея, код или геометрия | provenance record; license decision; описание independently implemented части |
| Снятие статуса experimental | выполнение всех критериев зрелости из следующего раздела и отдельная запись в decision log |

Изменение считается незаконченным, если обязательный gate заменён фразой «проверим позже».
Допускается слить research-only prototype без физического PASS, если он недоступен
пользовательскому plugin workflow, явно помечен experimental и имеет записанный следующий
experiment.

### 15.5. Settings-semantics matrix

Матрица ведётся для каждой настройки, которую plugin читает, рекомендует или изменяет:

| Поле | Смысл |
|---|---|
| setting key | точное имя PrusaSlicer option |
| owner | printer, print или filament preset |
| units/range | единицы, допустимый диапазон и sign convention |
| baseline | как ненулевое текущее значение входит в новую correction |
| axes/features | X/Y/Z, outer/inner/hole и область действия |
| transform order | где setting применяется относительно scale и других offsets |
| API support | read, write, save, active slicing state |
| verification source | source file/commit или официальная документация |
| failure behaviour | preview-only, blocked, attempted или confirmed |
| tests | zero/nonzero baseline, limits, unavailable API и readback mismatch |

Если хотя бы `baseline`, `transform order` или `API support` неизвестны, автоматический
apply этой настройки **MUST NOT** включаться. Calculation может остаться доступным с явной
оговоркой.

### 15.6. Error budget

Для каждого fitted или derived значения error budget должен различать как минимум:

- resolution, MPE/accuracy и zero drift инструмента;
- jaw placement и contact-force variation;
- operator и caliper effects;
- print-to-print variation;
- first layer, elephant foot, top surface и seam;
- flow, pressure advance, line width и contour construction;
- material shrinkage и thermal/conditioning effects;
- machine scale/skew;
- geometry/model sensitivity;
- residual и неопределённость выбора математической модели.

Error budget не обязан сразу давать одно combined число. Его первая задача — не позволить
назвать наблюдаемый intercept «ошибкой контура», если те же данные совместимы с несколькими
причинами.

### 15.7. Provenance и лицензии

На каждый внешний проект сохраняется запись:

```text
project
claim or borrowed principle
primary URL
source revision/date accessed
license URL/status
allowed use
copied/adapted/independently implemented
local files or decisions affected
```

`license_status = unknown` означает:

- не копировать модель, код, изображения или текст;
- не представлять отсутствие LICENSE как разрешение;
- можно независимо проверить общую инженерную гипотезу;
- до публикации производного материала выполнить отдельную лицензионную проверку.

### 15.8. Decision log

Минимальная запись решения:

```text
decision_id
date
status: PROPOSED / ACCEPTED / REJECTED / SUPERSEDED
scope
context
considered alternatives
evidence links
decision
consequences
revisit condition
affected artifact/protocol/solver/schema versions
```

Decision log фиксирует не каждую правку кода, а изменения смысла продукта или исследования.
Например: выбор XY-T вместо XY-C, отказ от автоматического contour apply, изменение
`0.03 мм`, принятие M1 или снятие experimental status.

### 15.9. Что не является постоянным правилом

Следующие значения и решения всегда остаются версионируемыми:

- `0.03 мм`, `20%` и другие acceptance margins;
- число operators, calipers, repeats и independent prints;
- конкретные номиналы и сечение эталона;
- выбор M0/M1/M2 и aggregation statistic;
- Quick/Precision composition;
- CSV/JSON fields и расположение файлов;
- перечень поддерживаемых PrusaSlicer versions.

Они могут изменяться на основании данных. Постоянным является требование изменить их
до начала нового trial, выдать новую версию и сохранить воспроизводимость старого результата.

## 16. Критерии зрелости

Проект можно перестать называть experimental только когда одновременно выполнено следующее:

- геометрия имеет фиксированную ревизию и однозначные измерительные поверхности;
- межоператорный, межинструментальный и межпечатный разброс опубликован;
- solver проходит synthetic/property tests и восстанавливает известные параметры;
- выбор M0/M1/M2 основан на заранее заданных правилах;
- correction улучшает независимые verification prints больше combined uncertainty;
- неудачное применение невозможно выдать за подтверждённое;
- результат полностью воспроизводится из сохранённых raw data и process signature;
- ограничения метода и лицензии сторонних идей задокументированы.

## 17. Итоговое направление

Самая сильная версия `dimensional-accuracy` выглядит так:

```text
версионированный эталон
→ строгий протокол измерения
→ сохранённые raw repeats
→ несколько объяснимых моделей
→ честный quality/refusal verdict
→ preview точного изменения профиля
→ write + readback
→ независимая verification print
→ воспроизводимый локальный отчёт
```

Главная дифференциация — не количество измерений и не сложность regression. Это доказуемая
цепочка от физической детали до проверенного изменения конкретного PrusaSlicer-профиля.

## 18. Реестр источников

### Прямые calibration-проекты

- K3D Accuracy: <https://k3d.tech/calibrations/accuracy/>
- K3D releases: <https://k3d.tech/calibrations/accuracy/releases/>
- Vector3D Calilantern: <https://vector3d.shop/products/calilantern-calibration-tool-mk2>
- Fleur de Cali: <https://github.com/dirtdigger/fleur_de_cali>
- Fleur de Cali worksheet: <https://github.com/dirtdigger/fleur_de_cali/blob/main/worksheet/docs/index.md>
- BoronTrident calibration: <https://github.com/cmdremily/BoronTrident/tree/master/calibration>
- LuckyPants tool: <https://www.thingiverse.com/thing%3A1982686>
- AP Engineering republish/remix: <https://www.makeronline.com/en/model/Shrinkage%20Calculator%20-%20Dimensional%20Calibration%20Tool%20v9%20%28Made%20by%20LuckyPants%29/20741.html>
- FDM Z-Dimensional Test: <https://thangs.com/designer/jcdeshaies/3d-model/FDM%2520Z-Dimensional%2520Test-1589673>
- ScanNTune: <https://github.com/jaak0b/ScanNTune>

### Slicer и метрология

- PrusaSlicer shrinkage implementation: <https://github.com/prusa3d/PrusaSlicer/blob/master/src/libslic3r/ShrinkageCompensation.cpp>
- PrusaSlicer FDM config definitions: <https://github.com/prusa3d/PrusaSlicer/blob/master/src/libslic3r/ConfigDefsFDM.cpp>
- PrusaSlicer contour slicing: <https://github.com/prusa3d/PrusaSlicer/blob/master/src/libslic3r/PrintObjectSlice.cpp>
- OrcaSlicer material shrinkage: <https://github.com/OrcaSlicer/OrcaSlicer/wiki/material_basic_information>
- OrcaSlicer tolerance calibration: <https://github.com/orcaslicer/orcaslicer/wiki/tolerance_calib>
- NIST Measurement Uncertainty: <https://www.nist.gov/itl/sed/topic-areas/measurement-uncertainty>
- NIST Gauge R&R: <https://www.itl.nist.gov/div898/handbook/mpc/section4/mpc46.htm>
- BIPM/JCGM Guides: <https://www.bipm.org/en/publications/guides>

### Соседние архитектурные проекты

- OpenDesignCore: <https://github.com/thewriterben/OpenDesignCore>
- AI Parts on Demand: <https://github.com/AlakazipLabs/ai-parts-on-demand>
- vcad: <https://github.com/ecto/vcad>
