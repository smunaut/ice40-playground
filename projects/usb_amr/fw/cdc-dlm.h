/*
 * cdc-dlm.h
 *
 * CDC Direct Line Modem control for MC97 modem
 *
 * Copyright (C) 2021 Sylvain Munaut
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

#pragma once

void cdc_dlm_init(void);
void cdc_dlm_poll(void);
