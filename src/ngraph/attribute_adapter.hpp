//*****************************************************************************
// Copyright 2017-2019 Intel Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//*****************************************************************************

#pragma once

#include "ngraph/enum_names.hpp"
#include "ngraph/type.hpp"

namespace ngraph
{
    /// Provides a generic way to access attribute values as strings for serialization
    class StringAdapter
    {
    public:
        virtual ~StringAdapter() {}
        static constexpr DiscreteTypeInfo type_info{"StringAdapter", 0};
        virtual const DiscreteTypeInfo& get_type_info() const { return type_info; }
        /// Returns the value as a string
        virtual std::string get_string() const = 0;
        ///
        virtual void set_string(const std::string& value) const = 0;
    };

    class IntegerVectorAdapter
    {
    public:
        virtual ~IntegerVectorAdapter(){};
        static constexpr DiscreteTypeInfo type_info{"StringAdapter", 0};
        virtual const DiscreteTypeInfo& get_type_info() const { return type_info; }
        /// Returns the value as an integer vector
        virtual std::vector<int64_t> get_vector() const = 0;
        virtual void set_vector(const std::vector<int64_t>& value) const = 0;
    };

    template <typename Type, typename Base>
    class TypeAdapter : public Base
    {
    public:
        operator Type&() const { return m_value; }
    protected:
        TypeAdapter(Type& value)
            : m_value(value)
        {
        }
        Type& m_value;
    };

    template <typename Type>
    class EnumAdapter : public TypeAdapter<Type, StringAdapter>
    {
    public:
        EnumAdapter(Type& value)
            : TypeAdapter<Type, StringAdapter>(value)
        {
        }
        static const DiscreteTypeInfo type_info;
        const DiscreteTypeInfo& get_type_info() const override { return type_info; }
        std::string get_string() const override
        {
            return as_string(TypeAdapter<Type, StringAdapter>::m_value);
        }
        void set_string(const std::string& value) const override
        {
            TypeAdapter<Type, StringAdapter>::m_value = as_enum<Type>(value);
        }
    };

    template <typename Type>
    class ObjectAdapter : public TypeAdapter<Type, StringAdapter>
    {
    public:
        ObjectAdapter(Type& value)
            : TypeAdapter<Type, StringAdapter>(value)
        {
        }
        static const DiscreteTypeInfo type_info;
        const DiscreteTypeInfo& get_type_info() const override { return type_info; }
        std::string get_string() const override { return "TODO"; }
        void set_string(const std::string& value) const override {}
    };

    class Shape;

    template <>
    class ObjectAdapter<Shape> : public TypeAdapter<Shape, IntegerVectorAdapter>
    {
    public:
        ObjectAdapter<Shape>(Shape& value)
            : TypeAdapter<Shape, IntegerVectorAdapter>(value)
        {
        }
        static constexpr DiscreteTypeInfo type_info{"ObjectAdapter<Shape>", 0};
        const DiscreteTypeInfo& get_type_info() const override { return type_info; }
        std::vector<int64_t> get_vector() const override;
        void set_vector(const std::vector<int64_t>& value) const override;
    };

    class Strides;
    template <>
    class ObjectAdapter<Strides> : public TypeAdapter<Strides, IntegerVectorAdapter>
    {
    public:
        ObjectAdapter<Strides>(Strides& value)
            : TypeAdapter<Strides, IntegerVectorAdapter>(value)
        {
        }
        static constexpr DiscreteTypeInfo type_info{"ObjectAdapter<Strides>", 0};
        const DiscreteTypeInfo& get_type_info() const override { return type_info; }
        std::vector<int64_t> get_vector() const override;
        void set_vector(const std::vector<int64_t>& value) const override;
    };

    class AxisSet;
    template <>
    class ObjectAdapter<AxisSet> : public TypeAdapter<AxisSet, IntegerVectorAdapter>
    {
    public:
        ObjectAdapter<AxisSet>(AxisSet& value)
            : TypeAdapter<AxisSet, IntegerVectorAdapter>(value)
        {
        }
        static constexpr DiscreteTypeInfo type_info{"ObjectAdapter<AxisSet>", 0};
        const DiscreteTypeInfo& get_type_info() const override { return type_info; }
        std::vector<int64_t> get_vector() const override;
        void set_vector(const std::vector<int64_t>& value) const override;
    };
}
