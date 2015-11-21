﻿using System;
using OpenQA.Selenium;

namespace Protractor
{
    public static class NgBy
    {
        public static By Binding(string binding)
        {
            return new JavaScriptBy(ClientSideScripts.FindBindings, binding);
        }

        [Obsolete("Use Model instead.")]
        public static By Input(string model)
        {
            return new JavaScriptBy(ClientSideScripts.FindModel, model);
        }

        public static By Model(string model)
        {
            return new JavaScriptBy(ClientSideScripts.FindModel, model);
        }

        [Obsolete("Use Model instead.")]
        public static By TextArea(string model)
        {
            return new JavaScriptBy(ClientSideScripts.FindModel, model);
        }

        [Obsolete("Use Model instead.")]
        public static By Select(string model)
        {
            return new JavaScriptBy(ClientSideScripts.FindModel, model);
        }

        public static By SelectedOption(string model)
        {
            return new JavaScriptBy(ClientSideScripts.FindSelectedOptions, model);
        }

        public static By Repeater(string repeat)
        {
            return new JavaScriptBy(ClientSideScripts.FindAllRepeaterRows, repeat);
        }
    }
}