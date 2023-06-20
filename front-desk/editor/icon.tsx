import * as React from 'react'
import {
    IconProps as SundryIconProps,
    Icon as SundryIcon,
    IconifyIcon,
    IconifyIconDefinition,
    setSundryIcons,
} from '@nathanstitt/sundry/ui'

import thumbsUp from '@iconify-icons/bi/hand-thumbs-up-fill'
import x from '@iconify-icons/bi/x'
import exclamationCircle from '@iconify-icons/bi/exclamation-circle-fill'
import exclamationTriangle from '@iconify-icons/bi/exclamation-triangle-fill'
import xCircle from '@iconify-icons/bi/x-circle'
import clock from '@iconify-icons/bi/clock'
import spin from '@iconify-icons/bi/arrow-clockwise'
import plusSquare from '@iconify-icons/bi/plus-square-fill'
import plus from '@iconify-icons/bi/plus'
import minusSquare from '@iconify-icons/bi/dash-square'
import close from '@iconify-icons/bi/x-square'


const SUNDRY_PACKAGED_ICONS = {
    thumbsUp,
    xSimple: x,
    exclamationCircle,
    exclamationTriangle,
    cancel: xCircle,
    clock,
    xCircle,
    spin,
    close,
    plusSquare,
    plus,
    minusSquare,
}
setSundryIcons(SUNDRY_PACKAGED_ICONS)

export const ICONS = {
    ...SUNDRY_PACKAGED_ICONS,
}

export type IconKey = keyof typeof ICONS
export type IconSpec = IconKey | IconifyIconDefinition | IconifyIcon

export interface IconProps extends Omit<SundryIconProps, 'icon'> {
    icon: IconSpec
    id?: string
    disabled?: boolean
}

export const Icon = React.forwardRef<SVGSVGElement, PropsWithOptionalChildren<IconProps>>((allProps, ref) => {
    const { icon, ...props } = allProps

    return <SundryIcon {...props} ref={ref} icon={typeof icon === 'object' ? icon : ICONS[icon]} />
})

Icon.displayName = 'Icon'
