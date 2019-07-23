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

#include "ngraph/op/erf.hpp"
#include <cmath>
#include "ngraph/builder/make_constant.hpp"
#include "ngraph/log.hpp"
#include "ngraph/op/exp.hpp"
#include "ngraph/op/multiply.hpp"
#include "ngraph/util.hpp"

using namespace std;
using namespace ngraph;

const string op::Erf::type_name{"Erf"};

shared_ptr<Node> op::Erf::copy_with_new_args(const NodeVector& new_args) const
{
    check_new_args_count(this, new_args);
    return make_shared<Erf>(new_args.at(0));
}

op::Erf::Erf(const Output<Node>& arg)
    : UnaryElementwiseArithmetic(arg)
{
    constructor_validate_and_infer_types();
}

// erf'(x) = 2 / sqrt(pi) * exp (-x^2)
void op::Erf::generate_adjoints(autodiff::Adjoints& adjoints, const NodeVector& deltas)
{
    auto delta = deltas.at(0);
    auto x = get_argument(0);
    auto coff = 2.0 / sqrt(M_PI);
    auto coff_node = builder::make_constant(x->get_element_type(), x->get_shape(), coff);

    shared_ptr<ngraph::Node> neg_one =
        builder::make_constant(x->get_element_type(), x->get_shape(), -1.0);

    auto deriv = coff_node * make_shared<ngraph::op::Exp>(neg_one * x * x);

    adjoints.add_delta(x, delta * deriv);
}
