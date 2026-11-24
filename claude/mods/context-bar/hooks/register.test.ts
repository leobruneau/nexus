import { expect, test } from 'claude-code/testing'

import { k, level } from './register'

const SURFACES = ['terminal', 'desktop'] as const

type TestArgs = Parameters<Parameters<typeof test>[1]>

const setupMeasure = ($: TestArgs[0], on: TestArgs[1]) => {
  on('session.measure', (_$, e) => ({ changed: e.changed }))
  return (context: { tokens?: number; window: number; percent?: number }) =>
    $.session.measure({ context, rateLimits: [], changed: ['context'] })
}

test('format', () => {
  expect(k(999)).toBe('999')
  expect(k(123456)).toBe('123.5K')
  expect(k(70000)).toBe('70.0K')
})

test('level', () => {
  expect(level(70_000)).toBe('success')
  expect(level(70_001)).toBe('warning')
  expect(level(140_000)).toBe('warning')
  expect(level(140_001)).toBe('error')
})

test('renders nothing before first session.measure and keeps beneath', async $ => {
  for (const surface of SURFACES) {
    const ui = await $.ui.mount({
      plugin: 'context-bar',
      surface,
      component: 'SessionMode',
      props: { modes: [] },
    })
    expect(await ui.keepsBeneath()).toBe(true)
    expect(await ui.find({ text: /%/ })).toBeUndefined()
    await ui.unmount()
  }
})

test('renders count and percentage on terminal and desktop with mode separator', async ($, on) => {
  const measure = setupMeasure($, on)
  await measure({ tokens: 50_000, window: 1_000_000, percent: 5 })

  for (const surface of SURFACES) {
    const bare = await $.ui.mount({
      plugin: 'context-bar',
      surface,
      component: 'SessionMode',
      props: { modes: [] },
    })
    expect(await bare.keepsBeneath()).toBe(true)
    const count = await bare.find({ type: 'Text', text: /^50\.0K$/ })
    expect(count?.props.color).toBe('success')
    expect(await bare.find({ type: 'Text', text: '(5%)' })).toBeDefined()
    expect(await bare.find({ text: /·/ })).toBeUndefined()
    await bare.unmount()

    const withMode = await $.ui.mount({
      plugin: 'context-bar',
      surface,
      component: 'SessionMode',
      props: { modes: ['focus'] },
    })
    expect(await withMode.keepsBeneath()).toBe(true)
    expect(await withMode.find({ type: 'Text', text: /·/ })).toBeDefined()
    expect(await withMode.find({ type: 'Text', text: '50.0K' })).toBeDefined()
    await withMode.unmount()
  }
})

test('applies warning and error color thresholds', async ($, on) => {
  const measure = setupMeasure($, on)
  await measure({ tokens: 80_000, window: 1_000_000, percent: 8 })
  const warnUi = await $.ui.mount({
    plugin: 'context-bar',
    surface: 'terminal',
    component: 'SessionMode',
    props: { modes: [] },
  })
  expect((await warnUi.find({ type: 'Text', text: /^80\.0K$/ }))?.props.color).toBe('warning')
  await warnUi.unmount()

  await measure({ tokens: 150_000, window: 1_000_000, percent: 15 })
  const errUi = await $.ui.mount({
    plugin: 'context-bar',
    surface: 'terminal',
    component: 'SessionMode',
    props: { modes: [] },
  })
  expect((await errUi.find({ type: 'Text', text: /^150\.0K$/ }))?.props.color).toBe('error')
  await errUi.unmount()
})

test('clears stale count on compaction or clear', async ($, on) => {
  const measure = setupMeasure($, on)
  await measure({ tokens: 50_000, window: 1_000_000, percent: 5 })
  await $.session.measure({
    context: { window: 1_000_000 },
    rateLimits: [],
    changed: ['context'],
  })

  const ui = await $.ui.mount({
    plugin: 'context-bar',
    surface: 'terminal',
    component: 'SessionMode',
    props: { modes: [] },
  })
  expect(await ui.keepsBeneath()).toBe(true)
  expect(await ui.find({ text: /%/ })).toBeUndefined()
  await ui.unmount()
})

test('composes with downstream SessionMode hooks', async ($, on) => {
  on('ui.render', { component: 'SessionMode' }, ($, e) => {
    const { Text } = $.ui.resolve(e)
    return h(Text, null, 'focus mode')
  })

  const measure = setupMeasure($, on)
  await measure({ tokens: 50_000, window: 1_000_000, percent: 5 })

  const ui = await $.ui.mount({
    plugin: 'context-bar',
    surface: 'terminal',
    component: 'SessionMode',
    props: { modes: ['focus'] },
  })
  expect(await ui.find({ type: 'Text', text: 'focus mode' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '50.0K' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '(5%)' })).toBeDefined()
  await ui.unmount()
})
