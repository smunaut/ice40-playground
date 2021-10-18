/*
 * console.h
 *
 * Copyright (C) 2021 Sylvain Munaut
 * SPDX-License-Identifier: MIT
 */

#pragma once

void console_init(void);
void console_poll(void);

char getchar(void);
int  getchar_nowait(void);
void putchar(char c);
void puts(const char *p);
int  printf(const char *fmt, ...);
